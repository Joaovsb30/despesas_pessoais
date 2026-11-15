import 'package:flutter/foundation.dart';

import '../data/expense_repository.dart';
import '../models/expense.dart';

DateTime monthOf(DateTime d) => DateTime(d.year, d.month);

class ExpenseStore extends ChangeNotifier {
  final ExpenseRepository _repo;

  ExpenseStore(this._repo);

  List<Expense> _expenses = [];
  int? _budgetCents;
  bool _loaded = false;

  bool get loaded => _loaded;
  List<Expense> get expenses => List.unmodifiable(_expenses);
  int? get monthlyBudgetCents => _budgetCents;

  Future<void> load() async {
    _expenses = await _repo.getAll();
    _budgetCents = await _repo.getMonthlyBudgetCents();
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

  Future<void> add(Expense e) async {
    _expenses.add(await _repo.insert(e));
    _sort();
    notifyListeners();
  }

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

  /// Desfaz uma exclusão, recriando o gasto (com novo id).
  Future<void> restore(Expense e) => add(e.copyWith());

  Future<void> setMonthlyBudget(int? cents) async {
    await _repo.setMonthlyBudgetCents(cents);
    _budgetCents = cents;
    notifyListeners();
  }

  List<Expense> forMonth(DateTime month) {
    final m = monthOf(month);
    return _expenses.where((e) => monthOf(e.date) == m).toList();
  }

  static int total(Iterable<Expense> list) =>
      list.fold(0, (sum, e) => sum + e.amountCents);

  /// Total por categoria, do maior para o menor.
  static List<MapEntry<String, int>> byCategory(Iterable<Expense> list) {
    final map = <String, int>{};
    for (final e in list) {
      map[e.categoryId] = (map[e.categoryId] ?? 0) + e.amountCents;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  /// Totais dos [count] meses terminando em [endMonth], do mais antigo ao mais recente.
  List<MapEntry<DateTime, int>> monthlyTotals(DateTime endMonth, int count) {
    final end = monthOf(endMonth);
    return List.generate(count, (i) {
      final m = DateTime(end.year, end.month - (count - 1 - i));
      return MapEntry(m, total(forMonth(m)));
    });
  }
}
