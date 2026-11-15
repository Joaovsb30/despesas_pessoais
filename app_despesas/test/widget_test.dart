import 'package:expenses/data/expense_repository.dart';
import 'package:expenses/main.dart';
import 'package:expenses/state/expense_store.dart';
import 'package:expenses/utils/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

class FakeAuth extends DeviceAuth {
  bool allow;
  int calls = 0;
  FakeAuth({this.allow = true});

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async {
    calls++;
    return allow;
  }
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!.replaceAll(' ', ' ');

Future<ExpenseStore> pumpApp(WidgetTester tester, {DeviceAuth? auth, ExpenseStore? store}) async {
  store ??= ExpenseStore(InMemoryExpenseRepository());
  await store.load();
  await tester.pumpWidget(ExpensesApp(store: store, auth: auth ?? FakeAuth()));
  await tester.pumpAndSettle();
  return store;
}

Future<void> addEntry(WidgetTester tester,
    {required String value, required String title, bool income = false, String? category}) async {
  await tester.tap(find.text('Novo'));
  await tester.pumpAndSettle();
  if (income) {
    await tester.tap(find.text('Receita'));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), value);
  await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), title);
  if (category != null) await tester.tap(find.text(category));
  await tester.tap(find.text(income ? 'Adicionar receita' : 'Adicionar gasto'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('gasto e receita aparecem no total e no saldo', (tester) async {
    await pumpApp(tester);
    expect(find.text('Nenhum lançamento neste mês'), findsOneWidget);

    await addEntry(tester, value: '42,90', title: 'Padaria', category: 'Mercado');
    expect(find.text('Padaria'), findsOneWidget);
    expect(textOf(tester, 'month-total'), 'R\$ 42,90');

    await addEntry(tester, value: '1000', title: 'Freela', income: true);
    expect(find.textContaining('1.000,00'), findsWidgets);
    expect(textOf(tester, 'month-total'), 'R\$ 42,90');
    final balance = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('month-balance')), matching: find.byType(Text)).last);
    expect(balance.data!.replaceAll(' ', ' '), 'R\$ 957,10');
  });

  testWidgets('compra parcelada cria uma parcela por mês', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '300');
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), 'Celular');
    await tester.scrollUntilVisible(find.text('Parcelado'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Parcelado'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.widgetWithText(TextFormField, 'Número de parcelas'), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.widgetWithText(TextFormField, 'Número de parcelas'), '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('3× de'), findsOneWidget);
    await tester.tap(find.text('Adicionar gasto'));
    await tester.pumpAndSettle();

    expect(store.expenses, hasLength(3));
    expect(store.expenses.map((e) => e.amountCents).toSet(), {10000});
    expect(find.text('Celular (1/3)'), findsOneWidget);
  });

  testWidgets('não salva sem valor', (tester) async {
    final store = await pumpApp(tester);
    await tester.tap(find.text('Novo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar gasto'));
    await tester.pumpAndSettle();
    expect(find.text('Informe um valor válido'), findsOneWidget);
    expect(store.expenses, isEmpty);
  });

  testWidgets('com bloqueio ativo, abre bloqueado e libera após autenticar', (tester) async {
    final auth = FakeAuth(allow: false);
    final store = ExpenseStore(InMemoryExpenseRepository());
    await store.load();
    await store.setLockEnabled(true);
    await pumpApp(tester, auth: auth, store: store);

    expect(find.text('Despesas bloqueado'), findsOneWidget);
    expect(auth.calls, 1);

    auth.allow = true;
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('Despesas bloqueado'), findsNothing);
    expect(find.text('Nenhum lançamento neste mês'), findsOneWidget);
  });

  testWidgets('busca encontra lançamentos de qualquer mês', (tester) async {
    final store = await pumpApp(tester);
    await addEntry(tester, value: '25', title: 'Farmácia', category: 'Saúde');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'farmacia');
    await tester.pumpAndSettle();
    expect(find.textContaining('1 lançamento'), findsOneWidget);
    expect(store.search('farmacia'), hasLength(1));
  });
}
