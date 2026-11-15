import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/category.dart';
import '../models/expense.dart';
import 'money.dart';

const _header = 'Data;Tipo;Descrição;Categoria;Valor;Observação';
final _date = DateFormat('dd/MM/yyyy');

String _cell(String v) =>
    RegExp(r'[;"\n\r]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;

/// CSV separado por ";" (abre direto no Excel/Sheets em português).
String expensesToCsv(List<Expense> expenses) {
  final buf = StringBuffer('$_header\n');
  for (final e in expenses) {
    buf.writeln([
      _date.format(e.date),
      e.isIncome ? 'Receita' : 'Despesa',
      _cell(e.title),
      _cell(ExpenseCategory.byId(e.categoryId).label),
      (e.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
      _cell(e.note ?? ''),
    ].join(';'));
  }
  return buf.toString();
}

/// Lê um CSV com ";" respeitando campos entre aspas (que podem ter ; e quebras de linha).
List<List<String>> parseCsvRows(String text) {
  if (text.startsWith('﻿')) text = text.substring(1);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ';') {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      if (row.any((v) => v.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      cell.write(c);
    }
  }
  row.add(cell.toString());
  if (row.any((v) => v.isNotEmpty)) rows.add(row);
  return rows;
}

class CsvImportResult {
  final List<Expense> expenses;
  final int skipped;

  const CsvImportResult(this.expenses, this.skipped);
}

/// Converte o CSV exportado pelo app de volta em lançamentos.
/// Aceita também o formato antigo, sem a coluna "Tipo".
CsvImportResult expensesFromCsv(String text) {
  final rows = parseCsvRows(text);
  if (rows.isEmpty) return const CsvImportResult([], 0);
  final hasType = rows.first.length >= 6 || rows.first.contains('Tipo');
  final body = rows.first.first.trim().toLowerCase() == 'data' ? rows.skip(1) : rows;

  final result = <Expense>[];
  var skipped = 0;
  for (final r in body) {
    try {
      final cols = hasType ? r : [r[0], 'Despesa', ...r.skip(1)];
      final income = cols[1].trim().toLowerCase().startsWith('receita');
      final cents = parseMoney(cols[4]);
      final title = cols[2].trim();
      if (cents == null || cents <= 0 || title.isEmpty) {
        skipped++;
        continue;
      }
      final note = cols.length > 5 ? cols[5].trim() : '';
      result.add(Expense(
        title: title,
        amountCents: cents,
        date: _date.parseStrict(cols[0].trim()),
        categoryId: ExpenseCategory.byLabel(cols[3], income: income).id,
        isIncome: income,
        note: note.isEmpty ? null : note,
      ));
    } catch (_) {
      skipped++;
    }
  }
  return CsvImportResult(result, skipped);
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
