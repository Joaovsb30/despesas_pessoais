import 'dart:async';
import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'receipt_parser.dart';

/// Resultado da leitura: o que foi entendido e a imagem guardada (se houver).
class ReceiptScan {
  final ReceiptData data;
  final String? imagePath;

  const ReceiptScan(this.data, this.imagePath);
}

/// Lê comprovantes. A implementação real usa OCR no próprio celular.
abstract class ReceiptReader {
  /// Imagem (jpg/png...) ou PDF.
  Future<ReceiptScan> scanFile(String path, {String? mimeType});

  /// Texto compartilhado direto (alguns bancos compartilham o comprovante como texto).
  Future<ReceiptScan> scanText(String text) async => ReceiptScan(ReceiptParser.parse(text), null);

  /// Apaga imagens de comprovantes que não pertencem a nenhum lançamento.
  Future<void> cleanup(Set<String> inUse) async {}
}

/// OCR com Google ML Kit (modelo embutido no app, funciona sem internet).
class OnDeviceReceiptReader extends ReceiptReader {
  Future<Directory> _dir() async {
    final dir = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'comprovantes'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _newName(String ext) => 'comprovante_${DateTime.now().millisecondsSinceEpoch}$ext';

  static bool isPdf(String path, String? mimeType) =>
      mimeType == 'application/pdf' || path.toLowerCase().endsWith('.pdf');

  /// Converte a 1ª página do PDF numa imagem PNG nítida o bastante para o OCR.
  Future<String> _pdfToImage(String pdfPath, Directory dir) async {
    final doc = await PdfDocument.openFile(pdfPath);
    try {
      final page = await doc.getPage(1);
      try {
        final scale = (1600 / page.width).clamp(1.5, 4.0);
        final image = await page.render(
          width: page.width * scale,
          height: page.height * scale,
          format: PdfPageImageFormat.png,
          backgroundColor: '#FFFFFF',
        );
        if (image == null) throw StateError('PDF sem página');
        final out = File(p.join(dir.path, _newName('.png')));
        await out.writeAsBytes(image.bytes);
        return out.path;
      } finally {
        await page.close();
      }
    } finally {
      await doc.close();
    }
  }

  @override
  Future<ReceiptScan> scanFile(String path, {String? mimeType}) async {
    final dir = await _dir();
    final String stored;
    if (isPdf(path, mimeType)) {
      stored = await _pdfToImage(path, dir);
    } else {
      final ext = p.extension(path).isEmpty ? '.jpg' : p.extension(path).toLowerCase();
      stored = (await File(path).copy(p.join(dir.path, _newName(ext)))).path;
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(stored));
      return ReceiptScan(ReceiptParser.parse(result.text), stored);
    } finally {
      await recognizer.close();
    }
  }

  @override
  Future<void> cleanup(Set<String> inUse) async {
    try {
      final dir = await _dir();
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final f in dir.list()) {
        if (f is File && !inUse.contains(f.path) && (await f.lastModified()).isBefore(cutoff)) {
          await f.delete();
        }
      }
    } catch (_) {
      // Limpeza é só economia de espaço; nunca deve atrapalhar o app.
    }
  }
}

/// Algo compartilhado com o app por outro app (banco, WhatsApp, galeria...).
class SharedReceipt {
  final String pathOrText;
  final bool isText;
  final String? mimeType;

  const SharedReceipt(this.pathOrText, {this.isText = false, this.mimeType});
}

/// Recebe comprovantes do menu "Compartilhar" do Android.
abstract class ReceiptInbox {
  Future<List<SharedReceipt>> initial();
  Stream<List<SharedReceipt>> get stream;
  void markHandled() {}
}

class ShareIntentInbox extends ReceiptInbox {
  static List<SharedReceipt> _convert(List<SharedMediaFile> files) => [
        for (final f in files)
          if (f.type == SharedMediaType.text || f.type == SharedMediaType.url)
            SharedReceipt(f.path, isText: true)
          else
            SharedReceipt(f.path, mimeType: f.mimeType),
      ];

  @override
  Future<List<SharedReceipt>> initial() async {
    try {
      return _convert(await ReceiveSharingIntent.instance.getInitialMedia());
    } catch (_) {
      return [];
    }
  }

  @override
  Stream<List<SharedReceipt>> get stream =>
      ReceiveSharingIntent.instance.getMediaStream().map(_convert).handleError((_) {});

  @override
  void markHandled() {
    ReceiveSharingIntent.instance.reset();
  }
}
