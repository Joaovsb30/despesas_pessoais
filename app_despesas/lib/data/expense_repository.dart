import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/expense.dart';
import '../models/recurring.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAll();
  Future<Expense> insert(Expense expense);
  Future<List<Expense>> insertAll(List<Expense> expenses);
  Future<void> update(Expense expense);
  Future<void> delete(int id);

  Future<List<RecurringRule>> getRecurring();
  Future<RecurringRule> insertRecurring(RecurringRule rule);
  Future<void> updateRecurring(RecurringRule rule);
  Future<void> deleteRecurring(int id);

  Future<Map<String, String>> getSettings();
  Future<void> setSetting(String key, String? value);
}

/// Guarda tudo num banco SQLite no próprio aparelho. Nada sai do celular.
class SqfliteExpenseRepository implements ExpenseRepository {
  Database? _db;

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE recurring(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        amount_cents INTEGER NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        day_of_month INTEGER NOT NULL,
        last_generated INTEGER NOT NULL
      )''');
  }

  Future<Database> get _database async {
    return _db ??= await openDatabase(
      p.join(await getDatabasesPath(), 'despesas.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount_cents INTEGER NOT NULL,
            date INTEGER NOT NULL,
            category TEXT NOT NULL,
            note TEXT,
            type TEXT NOT NULL DEFAULT 'expense',
            recurring_id INTEGER
          )''');
        await db.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
        await _createV2Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE expenses ADD COLUMN type TEXT NOT NULL DEFAULT 'expense'");
          await db.execute('ALTER TABLE expenses ADD COLUMN recurring_id INTEGER');
          await _createV2Tables(db);
        }
      },
    );
  }

  @override
  Future<List<Expense>> getAll() async {
    final rows = await (await _database).query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  @override
  Future<Expense> insert(Expense expense) async {
    final id = await (await _database).insert('expenses', expense.toMap());
    return expense.copyWith(id: id);
  }

  @override
  Future<List<Expense>> insertAll(List<Expense> expenses) async {
    final db = await _database;
    return db.transaction((txn) async {
      final saved = <Expense>[];
      for (final e in expenses) {
        saved.add(e.copyWith(id: await txn.insert('expenses', e.toMap())));
      }
      return saved;
    });
  }

  @override
  Future<void> update(Expense expense) async {
    await (await _database)
        .update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
  }

  @override
  Future<void> delete(int id) async {
    await (await _database).delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<RecurringRule>> getRecurring() async {
    final rows = await (await _database).query('recurring', orderBy: 'day_of_month, title');
    return rows.map(RecurringRule.fromMap).toList();
  }

  @override
  Future<RecurringRule> insertRecurring(RecurringRule rule) async {
    final id = await (await _database).insert('recurring', rule.toMap());
    return rule.copyWith(id: id);
  }

  @override
  Future<void> updateRecurring(RecurringRule rule) async {
    await (await _database)
        .update('recurring', rule.toMap(), where: 'id = ?', whereArgs: [rule.id]);
  }

  @override
  Future<void> deleteRecurring(int id) async {
    await (await _database).delete('recurring', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<Map<String, String>> getSettings() async {
    final rows = await (await _database).query('settings');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  @override
  Future<void> setSetting(String key, String? value) async {
    final db = await _database;
    if (value == null) {
      await db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await db.insert('settings', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

/// Usado nos testes.
class InMemoryExpenseRepository implements ExpenseRepository {
  final List<Expense> _items = [];
  final List<RecurringRule> _rules = [];
  final Map<String, String> _settings = {};
  int _nextId = 1;

  @override
  Future<List<Expense>> getAll() async => List.of(_items);

  @override
  Future<Expense> insert(Expense expense) async {
    final saved = expense.copyWith(id: _nextId++);
    _items.add(saved);
    return saved;
  }

  @override
  Future<List<Expense>> insertAll(List<Expense> expenses) async =>
      [for (final e in expenses) await insert(e)];

  @override
  Future<void> update(Expense expense) async {
    final i = _items.indexWhere((e) => e.id == expense.id);
    if (i >= 0) _items[i] = expense;
  }

  @override
  Future<void> delete(int id) async => _items.removeWhere((e) => e.id == id);

  @override
  Future<List<RecurringRule>> getRecurring() async => List.of(_rules);

  @override
  Future<RecurringRule> insertRecurring(RecurringRule rule) async {
    final saved = rule.copyWith(id: _nextId++);
    _rules.add(saved);
    return saved;
  }

  @override
  Future<void> updateRecurring(RecurringRule rule) async {
    final i = _rules.indexWhere((r) => r.id == rule.id);
    if (i >= 0) _rules[i] = rule;
  }

  @override
  Future<void> deleteRecurring(int id) async => _rules.removeWhere((r) => r.id == id);

  @override
  Future<Map<String, String>> getSettings() async => Map.of(_settings);

  @override
  Future<void> setSetting(String key, String? value) async =>
      value == null ? _settings.remove(key) : _settings[key] = value;
}
