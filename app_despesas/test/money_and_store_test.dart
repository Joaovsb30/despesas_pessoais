import 'package:expenses/data/expense_repository.dart';
import 'package:expenses/models/expense.dart';
import 'package:expenses/state/expense_store.dart';
import 'package:expenses/utils/csv_export.dart';
import 'package:expenses/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseMoney', () {
    test('formatos brasileiros e internacionais', () {
      expect(parseMoney('12,50'), 1250);
      expect(parseMoney('12.50'), 1250);
      expect(parseMoney('1.234,56'), 123456);
      expect(parseMoney('1.234'), 123400);
      expect(parseMoney('R\$ 30'), 3000);
      expect(parseMoney(' 0,1 '), 10);
      expect(parseMoney('19,99'), 1999);
    });

    test('entradas inválidas', () {
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('1,2,3'), isNull);
    });

    test('centsToInput', () {
      expect(centsToInput(123456), '1234,56');
      expect(centsToInput(5), '0,05');
    });
  });

  group('ExpenseStore', () {
    late ExpenseStore store;

    setUp(() async {
      store = ExpenseStore(InMemoryExpenseRepository());
      await store.load();
      await store.add(Expense(title: 'Mercado', amountCents: 20000, date: DateTime(2026, 11, 3), categoryId: 'mercado'));
      await store.add(Expense(title: 'Almoço', amountCents: 3500, date: DateTime(2026, 11, 10), categoryId: 'alimentacao'));
      await store.add(Expense(title: 'Jantar', amountCents: 6500, date: DateTime(2026, 11, 10), categoryId: 'alimentacao'));
      await store.add(Expense(title: 'Uber', amountCents: 2000, date: DateTime(2026, 10, 28), categoryId: 'transporte'));
    });

    test('filtra por mês, soma e ordena do mais recente', () {
      final nov = store.forMonth(DateTime(2026, 11));
      expect(nov.map((e) => e.title), ['Jantar', 'Almoço', 'Mercado']);
      expect(ExpenseStore.total(nov), 30000);
      expect(ExpenseStore.total(store.forMonth(DateTime(2026, 10))), 2000);
    });

    test('agrupa por categoria do maior para o menor', () {
      final cats = ExpenseStore.byCategory(store.forMonth(DateTime(2026, 11)));
      expect(cats.map((e) => e.key), ['mercado', 'alimentacao']);
      expect(cats.last.value, 10000);
    });

    test('totais mensais atravessando a virada do ano', () {
      final h = store.monthlyTotals(DateTime(2026, 11), 12);
      expect(h.first.key, DateTime(2025, 12));
      expect(h.last.key, DateTime(2026, 11));
      expect(h.last.value, 30000);
      expect(h[h.length - 2].value, 2000);
    });

    test('editar, excluir e desfazer', () async {
      final uber = store.expenses.firstWhere((e) => e.title == 'Uber');
      await store.update(uber.copyWith(amountCents: 2500));
      expect(ExpenseStore.total(store.forMonth(DateTime(2026, 10))), 2500);

      await store.remove(uber);
      expect(store.forMonth(DateTime(2026, 10)), isEmpty);
      await store.restore(uber);
      expect(store.forMonth(DateTime(2026, 10)).single.title, 'Uber');
    });

    test('orçamento', () async {
      await store.setMonthlyBudget(150000);
      expect(store.monthlyBudgetCents, 150000);
      await store.setMonthlyBudget(null);
      expect(store.monthlyBudgetCents, isNull);
    });
  });

  test('CSV escapa ponto e vírgula e aspas', () {
    final csv = expensesToCsv([
      Expense(title: 'Pizza; refri', amountCents: 4590, date: DateTime(2026, 11, 1), categoryId: 'lazer', note: 'com "amigos"'),
    ]);
    expect(csv.split('\n')[1], '01/11/2026;Despesa;"Pizza; refri";Lazer;45,90;"com ""amigos"""');
  });
}
