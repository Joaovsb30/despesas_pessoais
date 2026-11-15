import 'package:expenses/data/expense_repository.dart';
import 'package:expenses/main.dart';
import 'package:expenses/state/expense_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'pt_BR';
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('adiciona um gasto e ele aparece no total do mês', (tester) async {
    final store = ExpenseStore(InMemoryExpenseRepository());
    await store.load();
    await tester.pumpWidget(ExpensesApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum gasto neste mês'), findsOneWidget);

    await tester.tap(find.text('Novo gasto'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Valor'), '42,90');
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'), 'Padaria');
    await tester.tap(find.text('Mercado'));
    await tester.tap(find.text('Adicionar gasto'));
    await tester.pumpAndSettle();

    expect(find.text('Padaria'), findsOneWidget);
    final total = tester.widget<Text>(find.byKey(const Key('month-total'))).data!;
    expect(total.replaceAll(' ', ' '), 'R\$ 42,90');
  });

  testWidgets('não salva sem valor', (tester) async {
    final store = ExpenseStore(InMemoryExpenseRepository());
    await store.load();
    await tester.pumpWidget(ExpensesApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo gasto'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar gasto'));
    await tester.pumpAndSettle();

    expect(find.text('Informe um valor válido'), findsOneWidget);
    expect(store.expenses, isEmpty);
  });
}
