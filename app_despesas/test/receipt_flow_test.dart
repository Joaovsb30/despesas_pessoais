import 'dart:async';

import 'package:expenses/data/expense_repository.dart';
import 'package:expenses/main.dart';
import 'package:expenses/receipts/receipt_parser.dart';
import 'package:expenses/receipts/receipt_service.dart';
import 'package:expenses/state/expense_store.dart';
import 'package:expenses/utils/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Faz de conta que o OCR leu este texto do arquivo.
class FakeReader extends ReceiptReader {
  final Map<String, String> ocrText;
  FakeReader(this.ocrText);

  @override
  Future<ReceiptScan> scanFile(String path, {String? mimeType}) async =>
      ReceiptScan(ReceiptParser.parse(ocrText[path]!), '/fake/$path.png');
}

class FakeInbox extends ReceiptInbox {
  final controller = StreamController<List<SharedReceipt>>.broadcast();
  int handled = 0;

  @override
  Future<List<SharedReceipt>> initial() async => [];

  @override
  Stream<List<SharedReceipt>> get stream => controller.stream;

  @override
  void markHandled() => handled++;
}

class NoAuth extends DeviceAuth {
  @override
  Future<bool> authenticate(String reason) async => true;
}

final today = DateTime.now();
final hoje = DateFormat('dd/MM/yyyy').format(today);

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  Future<(ExpenseStore, FakeInbox)> start(WidgetTester tester, Map<String, String> ocr) async {
    final store = ExpenseStore(InMemoryExpenseRepository());
    await store.load();
    final inbox = FakeInbox();
    await tester.pumpWidget(ExpensesApp(
      store: store,
      auth: NoAuth(),
      receiptReader: FakeReader(ocr),
      receiptInbox: inbox,
    ));
    await tester.pumpAndSettle();
    return (store, inbox);
  }

  final pix = '''
Pix enviado
Valor
R\$ 89,90
$hoje 10:00
Destino
Nome
DROGARIA CENTRAL
''';

  testWidgets('comprovante compartilhado é lançado sozinho, com a imagem guardada', (tester) async {
    final (store, inbox) = await start(tester, {'pix.jpg': pix});

    inbox.controller.add([const SharedReceipt('pix.jpg', mimeType: 'image/jpeg')]);
    await tester.pumpAndSettle();

    final e = store.expenses.single;
    expect(e.amountCents, 8990);
    expect(e.title, 'Drogaria Central');
    expect(e.categoryId, 'saude');
    expect(e.receiptPath, '/fake/pix.jpg.png');
    expect(e.note, 'Pix');
    expect(inbox.handled, 1);
    expect(find.textContaining('Gasto adicionado: Drogaria Central'), findsOneWidget);
    expect(find.text('Drogaria Central'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);
  });

  testWidgets('texto compartilhado (sem imagem) também funciona', (tester) async {
    final (store, inbox) = await start(tester, {});
    inbox.controller.add([SharedReceipt('Pix recebido de R\$ 150,00 em $hoje. Quem pagou: Ana Lima', isText: true)]);
    await tester.pumpAndSettle();

    final e = store.expenses.single;
    expect(e.isIncome, isTrue);
    expect(e.amountCents, 15000);
    expect(e.receiptPath, isNull);
    expect(find.textContaining('Receita adicionada: Ana Lima'), findsOneWidget);
  });

  testWidgets('sem valor: abre o formulário preenchido para revisar', (tester) async {
    final (store, inbox) = await start(tester, {'foto.jpg': 'Pix enviado\nDestino\nNome\nJOSE SANTOS'});
    inbox.controller.add([const SharedReceipt('foto.jpg')]);
    await tester.pumpAndSettle();

    expect(store.expenses, isEmpty);
    expect(find.text('Novo gasto'), findsOneWidget);
    expect(find.text('Jose Santos'), findsOneWidget);
    expect(find.textContaining('Não encontrei o valor'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Ver comprovante'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ver comprovante'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '20');
    await tester.tap(find.text('Adicionar gasto'));
    await tester.pumpAndSettle();
    expect(store.expenses.single.receiptPath, '/fake/foto.jpg.png');
    expect(store.expenses.single.amountCents, 2000);
  });

  testWidgets('mesmo comprovante duas vezes pede revisão em vez de duplicar', (tester) async {
    final (store, inbox) = await start(tester, {'pix.jpg': pix});
    inbox.controller.add([const SharedReceipt('pix.jpg')]);
    await tester.pumpAndSettle();
    inbox.controller.add([const SharedReceipt('pix.jpg')]);
    await tester.pumpAndSettle();

    expect(store.expenses, hasLength(1));
    expect(find.text('Novo gasto'), findsOneWidget);
    expect(find.textContaining('Já existe um lançamento igual'), findsOneWidget);
  });
}
