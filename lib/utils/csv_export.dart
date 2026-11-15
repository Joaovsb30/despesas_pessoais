import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/expense.dart';

String _cell(String v) =>
    RegExp(r'[;"\n\r]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

/// CSV separado por ";" (abre direto no Excel/Sheets em português).
String expensesToCsv(List<Expense> expenses) {
  final date = DateFormat('dd/MM/yyyy');
  final buf = StringBuffer('Data;Descrição;Categoria;Valor;Observação\n');
  for (final e in expenses) {
    buf.writeln([
      date.format(e.date),
      _cell(e.title),
      _cell(ExpenseCategory.byId(e.categoryId).label),
      (e.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
      _cell(e.note ?? ''),
    ].join(';'));
  }
  return buf.toString();
}

Future<void> shareCsv(List<Expense> expenses) async {
  final dir = await getTemporaryDirectory();
  final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final file = File(p.join(dir.path, 'despesas_$stamp.csv'));
  // BOM para o Excel reconhecer os acentos
  await file.writeAsString('﻿${expensesToCsv(expenses)}');
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Despesas $stamp',
  ));
}
