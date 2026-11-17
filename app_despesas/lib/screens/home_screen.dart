import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../receipts/receipt_import.dart';
import '../receipts/receipt_service.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'expense_form_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseStore store;
  final ReceiptReader? receiptReader;
  final ReceiptInbox? receiptInbox;

  const HomeScreen({super.key, required this.store, this.receiptReader, this.receiptInbox});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _month = monthOf(DateTime.now());

  StreamSubscription<List<SharedReceipt>>? _shareSub;
  bool _importing = false;
  final _pending = <SharedReceipt>[];

  ExpenseStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    final inbox = widget.receiptInbox;
    if (inbox != null) {
      inbox.initial().then(_onShared);
      _shareSub = inbox.stream.listen(_onShared);
    }
    final reader = widget.receiptReader;
    if (reader != null) {
      store.ensureLoaded().then((_) =>
          reader.cleanup(store.expenses.map((e) => e.receiptPath).whereType<String>().toSet()));
    }
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _openForm([Expense? expense, Expense? draft, String? notice]) async {
    final now = DateTime.now();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExpenseFormScreen(
        store: store,
        expense: expense,
        draft: draft,
        notice: notice,
        initialDate: monthOf(now) == _month ? now : _month,
      ),
    ));
  }

  // ------------------------------------------------------------ comprovantes

  void _onShared(List<SharedReceipt> items) {
    if (items.isEmpty || widget.receiptReader == null) return;
    widget.receiptInbox?.markHandled();
    _pending.addAll(items);
    _drainShared();
  }

  Future<void> _drainShared() async {
    final reader = widget.receiptReader!;
    while (_pending.isNotEmpty && mounted && !_importing) {
      final item = _pending.removeAt(0);
      await _runImport(() => item.isText
          ? reader.scanText(item.pathOrText)
          : reader.scanFile(item.pathOrText, mimeType: item.mimeType));
    }
  }

  Future<void> _scanReceipt() async {
    final reader = widget.receiptReader;
    if (reader == null) return;
    final scan = await pickReceiptSource(context, reader);
    if (scan != null && mounted) await _runImport(scan);
  }

  Future<void> _runImport(Future<ReceiptScan> Function() scan) async {
    _importing = true;
    final nav = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Lendo comprovante...')),
            ],
          ),
        ),
      ),
    );
    final outcome = await importReceipt(store, scan);
    nav.pop();
    _importing = false;
    if (!mounted) return;

    switch (outcome) {
      case ReceiptAdded(:final expense):
        setState(() => _month = monthOf(expense.date));
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            duration: const Duration(seconds: 6),
            content: Text(describeAdded(expense)),
            action: SnackBarAction(
              label: 'Editar',
              onPressed: () {
                final current = store.expenses.where((e) => e.id == expense.id).firstOrNull;
                if (current != null) _openForm(current);
              },
            ),
          ));
      case ReceiptNeedsReview(:final draft, :final reason):
        await _openForm(null, draft, reason);
      case ReceiptFailed():
        messenger.showSnackBar(const SnackBar(
          content: Text('Não consegui ler esse arquivo. Tente um print ou PDF do comprovante.'),
        ));
    }
    if (_pending.isNotEmpty) _drainShared();
  }

  Future<void> _delete(Expense e) async {
    await store.remove(e);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('"${e.title}" excluído'),
        action: SnackBarAction(label: 'Desfazer', onPressed: () => store.restore(e)),
      ));
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final monthItems = store.forMonth(_month);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Despesas'),
            actions: [
              IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.search),
                onPressed: () => _push(SearchScreen(store: store, onOpen: _openForm)),
              ),
              if (widget.receiptReader != null)
                IconButton(
                  tooltip: 'Ler comprovante',
                  icon: const Icon(Icons.document_scanner_outlined),
                  onPressed: _scanReceipt,
                ),
              IconButton(
                tooltip: 'Resumo',
                icon: const Icon(Icons.insights),
                onPressed: () => _push(SummaryScreen(store: store, month: _month)),
              ),
              IconButton(
                tooltip: 'Mais',
                icon: const Icon(Icons.more_vert),
                onPressed: () => _push(SettingsScreen(store: store)),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Novo'),
          ),
          body: !store.loaded
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: MonthSelector(month: _month, onChanged: (m) => setState(() => _month = m)),
                    ),
                    SliverToBoxAdapter(
                      child: _SummaryCard(store: store, month: _month, items: monthItems),
                    ),
                    if (monthItems.isEmpty)
                      const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
                    else
                      ..._buildDayGroups(monthItems),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
        );
      },
    );
  }

  /// Só gastos: total gasto. Com receita no dia: saldo com sinal.
  static String _dayTotal(List<Expense> day) {
    if (!day.any((e) => e.isIncome)) return formatCents(ExpenseStore.total(day));
    final b = ExpenseStore.balance(day);
    return '${b >= 0 ? '+' : '−'} ${formatCents(b.abs())}';
  }

  List<Widget> _buildDayGroups(List<Expense> items) {
    final groups = <DateTime, List<Expense>>{};
    for (final e in items) {
      groups.putIfAbsent(e.date, () => []).add(e);
    }
    final dayFormat = DateFormat("EEE, d 'de' MMM");
    final theme = Theme.of(context);
    return [
      for (final entry in groups.entries) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    capitalize(dayFormat.format(entry.key)),
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                  ),
                ),
                Text(_dayTotal(entry.value), style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ),
        SliverList.list(
          children: [
            for (final e in entry.value)
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: theme.colorScheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
                ),
                onDismissed: (_) => _delete(e),
                child: ExpenseTile(e, onTap: () => _openForm(e)),
              ),
          ],
        ),
      ],
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  final ExpenseStore store;
  final DateTime month;
  final List<Expense> items;

  const _SummaryCard({required this.store, required this.month, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = scheme.onPrimaryContainer;
    final spent = ExpenseStore.total(ExpenseStore.onlyExpenses(items));
    final income = ExpenseStore.total(ExpenseStore.onlyIncome(items));
    final balance = income - spent;
    final previous = ExpenseStore.total(
        ExpenseStore.onlyExpenses(store.forMonth(DateTime(month.year, month.month - 1))));
    final budget = store.monthlyBudgetCents;
    final over = store.overBudgetCategories(month);
    final top = ExpenseStore.byCategory(items).take(3).toList();

    String? comparison;
    if (previous > 0) {
      final pct = ((spent - previous) / previous * 100).round();
      comparison = pct == 0 ? 'Igual ao mês anterior' : '${pct > 0 ? '+' : ''}$pct% vs. mês anterior';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gastos do mês', style: theme.textTheme.labelLarge?.copyWith(color: on)),
            const SizedBox(height: 4),
            Text(
              formatCents(spent),
              key: const Key('month-total'),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: on),
            ),
            if (comparison != null)
              Text(comparison, style: theme.textTheme.bodySmall?.copyWith(color: on)),
            if (income > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _MiniStat(label: 'Receitas', value: formatCents(income))),
                  Expanded(
                    child: _MiniStat(
                      key: const Key('month-balance'),
                      label: 'Saldo',
                      value: formatCents(balance),
                      color: balance < 0 ? scheme.error : null,
                    ),
                  ),
                ],
              ),
            ],
            if (budget != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (spent / budget).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: spent > budget ? scheme.error : scheme.primary,
                  backgroundColor: scheme.surface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                spent > budget
                    ? 'Passou ${formatCents(spent - budget)} do orçamento de ${formatCents(budget)}'
                    : 'Restam ${formatCents(budget - spent)} de ${formatCents(budget)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: spent > budget ? scheme.error : on,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            for (final o in over)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: scheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${ExpenseCategory.byId(o.key).label}: ${formatCents(o.value.$1)} '
                        'de ${formatCents(o.value.$2)} (limite estourado)',
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in top)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(ExpenseCategory.byId(t.key).icon,
                          size: 16, color: ExpenseCategory.byId(t.key).color),
                      label: Text('${ExpenseCategory.byId(t.key).label} ${formatCents(t.value)}'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _MiniStat({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final on = theme.colorScheme.onPrimaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: on)),
        Text(value,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color ?? on)),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text('Nenhum lançamento neste mês', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Toque em "Novo" para começar.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
