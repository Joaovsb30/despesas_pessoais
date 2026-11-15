import 'package:expenses/data/expense_repository.dart';
import 'package:expenses/models/expense.dart';
import 'package:expenses/state/expense_store.dart';
import 'package:expenses/utils/csv_export.dart';
import 'package:flutter_test/flutter_test.dart';

Expense gasto(String t, int c, DateTime d, [String cat = 'outros']) =>
    Expense(title: t, amountCents: c, date: d, categoryId: cat);

void main() {
  group('Parcelamento', () {
    test('divide o valor e joga a sobra dos centavos na 1ª parcela', () {
      final p = ExpenseStore.buildInstallments(gasto('TV', 10000, DateTime(2026, 1, 31), 'compras'), 3);
      expect(p.map((e) => e.amountCents), [3334, 3333, 3333]);
      expect(ExpenseStore.total(p), 10000);
      expect(p.map((e) => e.title), ['TV (1/3)', 'TV (2/3)', 'TV (3/3)']);
      // 31/jan -> 28/fev -> 31/mar
      expect(p.map((e) => e.date), [DateTime(2026, 1, 31), DateTime(2026, 2, 28), DateTime(2026, 3, 31)]);
    });
  });

  group('Recorrentes', () {
    test('lança os meses que faltam até o mês atual, uma vez só', () async {
      final repo = InMemoryExpenseRepository();
      var now = DateTime(2026, 11, 15);
      var store = ExpenseStore(repo, now: () => now);
      await store.load();

      await store.addRecurring(gasto('Aluguel', 150000, DateTime(2026, 8, 31), 'moradia'));
      final dates = store.expenses.map((e) => e.date).toList()..sort();
      expect(dates, [DateTime(2026, 8, 31), DateTime(2026, 9, 30), DateTime(2026, 10, 31), DateTime(2026, 11, 30)]);
      expect(store.expenses.every((e) => e.recurringId != null), isTrue);

      // Reabrir no mesmo mês não duplica
      store = ExpenseStore(repo, now: () => now);
      await store.load();
      expect(store.expenses, hasLength(4));

      // Mês seguinte: cria só dezembro
      now = DateTime(2026, 12, 2);
      store = ExpenseStore(repo, now: () => now);
      await store.load();
      expect(store.forMonth(DateTime(2026, 12)).single.date, DateTime(2026, 12, 31));

      // Parar de repetir mantém o que já foi lançado
      await store.removeRecurring(store.recurring.single);
      now = DateTime(2027, 2, 1);
      store = ExpenseStore(repo, now: () => now);
      await store.load();
      expect(store.expenses, hasLength(5));
      expect(store.recurring, isEmpty);
    });
  });

  group('Receitas, orçamentos e busca', () {
    late ExpenseStore store;
    setUp(() async {
      store = ExpenseStore(InMemoryExpenseRepository());
      await store.load();
      await store.addAll([
        Expense(title: 'Salário', amountCents: 500000, date: DateTime(2026, 11, 5), categoryId: 'salario', isIncome: true),
        gasto('Almoço no Café', 4500, DateTime(2026, 11, 6), 'alimentacao'),
        gasto('Show', 30000, DateTime(2026, 11, 7), 'lazer'),
      ]);
    });

    test('saldo e receitas fora das categorias de gasto', () {
      final nov = store.forMonth(DateTime(2026, 11));
      expect(ExpenseStore.balance(nov), 500000 - 34500);
      expect(ExpenseStore.byCategory(nov).map((e) => e.key), ['lazer', 'alimentacao']);
      expect(store.monthlyTotals(DateTime(2026, 11), 1).single.value, 34500);
    });

    test('alerta de categoria que estourou o limite', () async {
      await store.setCategoryBudget('lazer', 20000);
      await store.setCategoryBudget('alimentacao', 10000);
      final over = store.overBudgetCategories(DateTime(2026, 11));
      expect(over.single.key, 'lazer');
      expect(over.single.value, (30000, 20000));
      await store.setCategoryBudget('lazer', null);
      expect(store.overBudgetCategories(DateTime(2026, 11)), isEmpty);
    });

    test('busca ignora acentos e maiúsculas e olha a categoria', () {
      expect(store.search('cafe').single.title, 'Almoço no Café');
      expect(store.search('ALMOCO').single.title, 'Almoço no Café');
      expect(store.search('lazer').single.title, 'Show');
      expect(store.search('   '), isEmpty);
    });
  });

  group('Backup CSV', () {
    test('exportar e importar devolve os mesmos lançamentos', () {
      final original = [
        Expense(title: 'Pizza; refri', amountCents: 4590, date: DateTime(2026, 11, 1), categoryId: 'lazer', note: 'com "amigos"\ne família'),
        Expense(title: 'Salário', amountCents: 500000, date: DateTime(2026, 11, 5), categoryId: 'salario', isIncome: true),
      ];
      final back = expensesFromCsv('﻿${expensesToCsv(original)}');
      expect(back.skipped, 0);
      expect(back.expenses, hasLength(2));
      for (var i = 0; i < 2; i++) {
        expect(back.expenses[i].toMap(), original[i].toMap());
      }
    });

    test('aceita o formato antigo (sem coluna Tipo) e ignora linhas ruins', () {
      const old = 'Data;Descrição;Categoria;Valor;Observação\r\n'
          '03/11/2026;Mercado;Mercado;200,00;\r\n'
          'data errada;X;Lazer;10,00;\r\n'
          '04/11/2026;Sem valor;Lazer;;\r\n';
      final r = expensesFromCsv(old);
      expect(r.expenses.single.title, 'Mercado');
      expect(r.expenses.single.amountCents, 20000);
      expect(r.expenses.single.categoryId, 'mercado');
      expect(r.expenses.single.isIncome, isFalse);
      expect(r.skipped, 2);
    });
  });
}
