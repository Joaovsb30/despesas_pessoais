import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/expense_repository.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/recurring.dart';

DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

int daysInMonth(DateTime month) => DateTime(month.year, month.month + 1, 0).day;

/// Data no [month] para o dia [day], caindo no último dia em meses mais curtos.
DateTime clampedDate(DateTime month, int day) =>
    DateTime(month.year, month.month, day.clamp(1, daysInMonth(month)));

class ExpenseStore extends ChangeNotifier {
  static const _monthlyBudgetKey = 'monthly_budget';
  static const _categoryBudgetPrefix = 'budget:';
  static const _lockKey = 'lock_enabled';

  final ExpenseRepository _repo;

  /// Relógio injetável para testes.
  final DateTime Function() _now;

  ExpenseStore(this._repo, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  List<Expense> _expenses = [];
  List<RecurringRule> _recurring = [];
  Map<String, String> _settings = {};
  bool _loaded = false;

  bool get loaded => _loaded;
  List<Expense> get expenses => List.unmodifiable(_expenses);
  List<RecurringRule> get recurring => List.unmodifiable(_recurring);

  Future<void> load() async {
    _expenses = await _repo.getAll();
    _recurring = await _repo.getRecurring();
    _settings = await _repo.getSettings();
    await _generateRecurring();
    _sort();
    _loaded = true;
    notifyListeners();
  }

  void _sort() {
    _expenses.sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }

  // ---------------------------------------------------------------- lançamentos

  Future<Expense> add(Expense e) async {
    final saved = await _repo.insert(e);
    _expenses.add(saved);
    _sort();
    notifyListeners();
    return saved;
  }

  /// Já existe um lançamento com mesma descrição, valor e data? (ex.: comprovante enviado 2 vezes)
  bool hasDuplicate(Expense e) => _expenses.any((x) =>
      x.amountCents == e.amountCents && x.date == e.date && x.title == e.title && x.isIncome == e.isIncome);

  /// Espera o banco terminar de carregar.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final done = Completer<void>();
    void check() {
      if (_loaded && !done.isCompleted) done.complete();
    }
    addListener(check);
    await done.future;
    removeListener(check);
  }

  Future<void> addAll(List<Expense> list) async {
    if (list.isEmpty) return;
    _expenses.addAll(await _repo.insertAll(list));
    _sort();
    notifyListeners();
  }

  /// Divide [total] em [count] parcelas mensais a partir de [base].date.
  /// Os centavos que sobram da divisão vão para a primeira parcela.
  static List<Expense> buildInstallments(Expense base, int count) {
    final each = base.amountCents ~/ count;
    final remainder = base.amountCents - each * count;
    final start = monthOf(base.date);
    return List.generate(count, (i) {
      return base.copyWith(
        title: '${base.title} (${i + 1}/$count)',
        amountCents: each + (i == 0 ? remainder : 0),
        date: clampedDate(DateTime(start.year, start.month + i), base.date.day),
      );
    });
  }

  Future<void> addInstallments(Expense base, int count) =>
      addAll(buildInstallments(base, count));

  Future<void> update(Expense e) async {
    await _repo.update(e);
    final i = _expenses.indexWhere((x) => x.id == e.id);
    if (i >= 0) _expenses[i] = e;
    _sort();
    notifyListeners();
  }

  Future<void> remove(Expense e) async {
    // Tira da lista antes de ir ao banco, para o Dismissible sumir na hora.
    _expenses.removeWhere((x) => x.id == e.id);
    notifyListeners();
    await _repo.delete(e.id!);
  }

  /// Desfaz uma exclusão, recriando o lançamento (com novo id).
  Future<Expense> restore(Expense e) => add(e.copyWith());

  // ---------------------------------------------------------------- recorrentes

  /// Cria a regra e já lança o mês de [first].date (e os meses seguintes até hoje).
  Future<void> addRecurring(Expense first) async {
    final start = monthOf(first.date);
    final rule = await _repo.insertRecurring(RecurringRule(
      title: first.title,
      amountCents: first.amountCents,
      categoryId: first.categoryId,
      isIncome: first.isIncome,
      note: first.note,
      dayOfMonth: first.date.day,
      lastGeneratedMonth: DateTime(start.year, start.month - 1),
    ));
    _recurring.add(rule);
    await _generateRecurring();
    _sort();
    notifyListeners();
  }

  /// Para de repetir. Os lançamentos já criados continuam.
  Future<void> removeRecurring(RecurringRule rule) async {
    await _repo.deleteRecurring(rule.id!);
    _recurring.removeWhere((r) => r.id == rule.id);
    notifyListeners();
  }

  /// Cria os lançamentos das regras recorrentes até o mês atual (inclusive).
  Future<void> _generateRecurring() async {
    final current = monthOf(_now());
    for (var i = 0; i < _recurring.length; i++) {
      var rule = _recurring[i];
      final pending = <Expense>[];
      var m = DateTime(rule.lastGeneratedMonth.year, rule.lastGeneratedMonth.month + 1);
      while (!m.isAfter(current)) {
        pending.add(Expense(
          title: rule.title,
          amountCents: rule.amountCents,
          date: clampedDate(m, rule.dayOfMonth),
          categoryId: rule.categoryId,
          note: rule.note,
          isIncome: rule.isIncome,
          recurringId: rule.id,
        ));
        m = DateTime(m.year, m.month + 1);
      }
      if (pending.isEmpty) continue;
      _expenses.addAll(await _repo.insertAll(pending));
      rule = rule.copyWith(lastGeneratedMonth: monthOf(pending.last.date));
      await _repo.updateRecurring(rule);
      _recurring[i] = rule;
    }
  }

  // ---------------------------------------------------------------- configurações

  int? get monthlyBudgetCents => int.tryParse(_settings[_monthlyBudgetKey] ?? '');

  Future<void> setMonthlyBudget(int? cents) => _setSetting(_monthlyBudgetKey, cents?.toString());

  Map<String, int> get categoryBudgets => {
        for (final e in _settings.entries)
          if (e.key.startsWith(_categoryBudgetPrefix) && int.tryParse(e.value) != null)
            e.key.substring(_categoryBudgetPrefix.length): int.parse(e.value),
      };

  Future<void> setCategoryBudget(String categoryId, int? cents) =>
      _setSetting('$_categoryBudgetPrefix$categoryId', cents?.toString());

  bool get lockEnabled => _settings[_lockKey] == '1';

  Future<void> setLockEnabled(bool value) => _setSetting(_lockKey, value ? '1' : null);

  Future<void> _setSetting(String key, String? value) async {
    await _repo.setSetting(key, value);
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- consultas

  List<Expense> forMonth(DateTime month) {
    final m = monthOf(month);
    return _expenses.where((e) => monthOf(e.date) == m).toList();
  }

  static Iterable<Expense> onlyExpenses(Iterable<Expense> list) => list.where((e) => !e.isIncome);
  static Iterable<Expense> onlyIncome(Iterable<Expense> list) => list.where((e) => e.isIncome);

  static int total(Iterable<Expense> list) => list.fold(0, (sum, e) => sum + e.amountCents);

  /// Receitas menos despesas.
  static int balance(Iterable<Expense> list) => list.fold(0, (sum, e) => sum + e.signedCents);

  /// Total de despesas por categoria, do maior para o menor.
  static List<MapEntry<String, int>> byCategory(Iterable<Expense> list) {
    final map = <String, int>{};
    for (final e in onlyExpenses(list)) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amountCents;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Categorias que passaram do limite no mês: id -> (gasto, limite).
  List<MapEntry<String, (int, int)>> overBudgetCategories(DateTime month) {
    final spent = Map.fromEntries(byCategory(forMonth(month)));
    return [
      for (final b in categoryBudgets.entries)
        if ((spent[b.key] ?? 0) > b.value) MapEntry(b.key, (spent[b.key]!, b.value)),
    ];
  }

  /// Total de despesas dos [count] meses terminando em [endMonth], do mais antigo ao mais recente.
  List<MapEntry<DateTime, int>> monthlyTotals(DateTime endMonth, int count) {
    final end = monthOf(endMonth);
    return List.generate(count, (i) {
      final m = DateTime(end.year, end.month - (count - 1 - i));
      return MapEntry(m, total(onlyExpenses(forMonth(m))));
    });
  }

  /// Busca por descrição, observação ou categoria, sem diferenciar acentos/maiúsculas.
  List<Expense> search(String query) {
    final q = normalize(query.trim());
    if (q.isEmpty) return [];
    return _expenses.where((e) {
      final haystack = normalize(
          '${e.title} ${e.note ?? ''} ${ExpenseCategory.byId(e.categoryId).label}');
      return haystack.contains(q);
    }).toList();
  }

  static String normalize(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      buf.write(i >= 0 ? to[i] : ch);
    }
    return buf.toString();
  }
}
