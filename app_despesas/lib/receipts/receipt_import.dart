import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';
import 'receipt_service.dart';

/// Resultado de importar um comprovante, para a tela inicial reagir.
sealed class ReceiptImportOutcome {}

/// Lançado automaticamente.
class ReceiptAdded extends ReceiptImportOutcome {
  final Expense expense;
  ReceiptAdded(this.expense);
}

/// Precisa de revisão (sem valor ou parece repetido): abrir o formulário com este rascunho.
class ReceiptNeedsReview extends ReceiptImportOutcome {
  final Expense draft;
  final String reason;
  ReceiptNeedsReview(this.draft, this.reason);
}

class ReceiptFailed extends ReceiptImportOutcome {}

/// Lê o comprovante e decide: lançar sozinho ou pedir revisão.
Future<ReceiptImportOutcome> importReceipt(
  ExpenseStore store,
  Future<ReceiptScan> Function() scan, {
  DateTime Function() now = DateTime.now,
}) async {
  final ReceiptScan result;
  try {
    result = await scan();
  } catch (_) {
    return ReceiptFailed();
  }
  final d = result.data;
  final draft = Expense(
    title: d.title,
    amountCents: d.amountCents ?? 0,
    date: d.date ?? now(),
    categoryId: d.categoryId,
    isIncome: d.isIncome,
    note: d.kind,
    receiptPath: result.imagePath,
  );
  await store.ensureLoaded();
  if (d.amountCents == null) {
    return ReceiptNeedsReview(draft, 'Não encontrei o valor no comprovante. Confira os dados.');
  }
  if (store.hasDuplicate(draft)) {
    return ReceiptNeedsReview(draft, 'Já existe um lançamento igual. Confira antes de salvar.');
  }
  return ReceiptAdded(await store.add(draft));
}

/// Pergunta de onde vem o comprovante (câmera, galeria ou arquivo) e lê.
Future<Future<ReceiptScan> Function()?> pickReceiptSource(BuildContext context, ReceiptReader reader) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Dica: no app do banco, toque em Compartilhar no comprovante e escolha "Despesas".'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Tirar foto do comprovante'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('Escolher da galeria (print)'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Abrir PDF ou arquivo'),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  if (choice == 'file') {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return null;
    final f = files.first;
    final path = f.path;
    if (path == null) return null;
    return () => reader.scanFile(path, mimeType: OnDeviceReceiptReader.isPdf(f.name, null) ? 'application/pdf' : null);
  }
  final image = await ImagePicker().pickImage(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
    imageQuality: 92,
  );
  if (image == null) return null;
  return () => reader.scanFile(image.path, mimeType: image.mimeType);
}

String describeAdded(Expense e) =>
    '${e.isIncome ? 'Receita adicionada' : 'Gasto adicionado'}: ${e.title} · ${formatCents(e.amountCents)}';
