import 'dart:io';

import 'package:flutter/material.dart';

/// Mostra a imagem do comprovante com zoom.
class ReceiptViewerScreen extends StatelessWidget {
  final String path;

  const ReceiptViewerScreen({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comprovante')),
      backgroundColor: Colors.black,
      body: InteractiveViewer(
        maxScale: 6,
        child: Center(
          child: Image.file(
            File(path),
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('A imagem deste comprovante não está mais no celular.',
                  style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}
