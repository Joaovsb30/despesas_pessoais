import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAll();
  Future<Expense> insert(Expense expense);
  Future<void> update(Expense expense);
  Future<void> delete(int id);
  Future<int?> getMonthlyBudgetCents();
  Future<void> setMonthlyBudgetCents(int? cents);
}

/// Guarda tudo num banco SQLite no próprio aparelho. Nada sai do celular.
class SqfliteExpenseRepository implements ExpenseRepository {
  Database? _db;

  Future<Database> get _database async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'despesas.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount_cents INTEGER NOT NULL,
            date INTEGER NOT NULL,
            category TEXT NOT NULL,
            note TEXT
          )''');
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await db.execute(
            'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      },
    );
  }

  @override
  Future<List<Expense>> getAll() async {
    final rows = await (await _database)
        .query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  @override
  Future<Expense> insert(Expense expense) async {
    final id = await (await _database).insert('expenses', expense.toMap());
    return expense.copyWith(id: id);
  }

  @override
  Future<void> update(Expense expense) async {
    await (await _database).update('expenses', expense.toMap(),
        where: 'id = ?', whereArgs: [expense.id]);
  }

  @override
  Future<void> delete(int id) async {
    await (await _database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int?> getMonthlyBudgetCents() async {
    final rows = await (await _database).query('settings',
        where: 'key = ?', whereArgs: ['monthly_budget']);
    if (rows.isEmpty) return null;
    return int.tryParse(rows.first['value'] as String);
  }

  @override
  Future<void> setMonthlyBudgetCents(int? cents) async {
    final db = await _database;
    if (cents == null) {
      await db.delete('settings', where: 'key = ?', whereArgs: ['monthly_budget']);
    } else {
      await db.insert('settings', {'key': 'monthly_budget', 'value': '$cents'},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

/// Usado nos testes.
class InMemoryExpenseRepository implements ExpenseRepository {
  final List<Expense> _items = [];
  int _nextId = 1;
  int? _budget;

  @override
  Future<List<Expense>> getAll() async => List.of(_items);

  @override
  Future<Expense> insert(Expense expense) async {
    final saved = expense.copyWith(id: _nextId++);
    _items.add(saved);
    return saved;
  }

  @override
  Future<void> update(Expense expense) async {
    final i = _items.indexWhere((e) => e.id == expense.id);
    if (i >= 0) _items[i] = expense;
  }

  @override
  Future<void> delete(int id) async => _items.removeWhere((e) => e.id == id);

  @override
  Future<int?> getMonthlyBudgetCents() async => _budget;

  @override
  Future<void> setMonthlyBudgetCents(int? cents) async => _budget = cents;
}
