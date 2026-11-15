import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/csv_export.dart';
import '../utils/money.dart';
import '../widgets/common.dart';
import 'expense_form_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  final ExpenseStore store;

  const HomeScreen({super.key, required this.store});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _month = monthOf(DateTime.now());

  ExpenseStore get store => widget.store;

  Future<void> _openForm([Expense? expense]) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ExpenseFormScreen(
        store: store,
        expense: expense,
        initialDate: _defaultDateForMonth(),
      ),
    ));
  }

  DateTime _defaultDateForMonth() {
    final now = DateTime.now();
    return monthOf(now) == _month ? now : _month;
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

  Future<void> _editBudget() async {
    final controller = TextEditingController(
      text: store.monthlyBudgetCents == null ? '' : centsToInput(store.monthlyBudgetCents!),
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Orçamento mensal'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: 'R\$ ',
            hintText: 'Ex.: 3000,00',
            helperText: 'Deixe vazio para não usar orçamento',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final cents = parseMoney(result);
    await store.setMonthlyBudget(cents != null && cents > 0 ? cents : null);
  }

  Future<void> _export() async {
    if (store.expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum gasto para exportar.')));
      return;
    }
    await shareCsv(store.expenses);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final monthExpenses = store.forMonth(_month);
        return Scaffold(
          appBar: AppBar(
            title: const Text('Despesas'),
            actions: [
              IconButton(
                tooltip: 'Resumo',
                icon: const Icon(Icons.insights),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SummaryScreen(store: store, month: _month),
                )),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'budget' ? _editBudget() : _export(),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'budget',
                    child: ListTile(leading: Icon(Icons.savings), title: Text('Orçamento mensal')),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: ListTile(leading: Icon(Icons.ios_share), title: Text('Exportar CSV (backup)')),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Novo gasto'),
          ),
          body: !store.loaded
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: MonthSelector(
                        month: _month,
                        onChanged: (m) => setState(() => _month = m),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: _SummaryCard(
                        store: store,
                        month: _month,
                        monthExpenses: monthExpenses,
                      ),
                    ),
                    if (monthExpenses.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(),
                      )
                    else
                      ..._buildDayGroups(monthExpenses),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
        );
      },
    );
  }

  List<Widget> _buildDayGroups(List<Expense> expenses) {
    final groups = <DateTime, List<Expense>>{};
    for (final e in expenses) {
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
                Text(formatCents(ExpenseStore.total(entry.value)),
                    style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ),
        SliverList.list(
          children: [for (final e in entry.value) _ExpenseTile(e, onTap: () => _openForm(e), onDelete: () => _delete(e))],
        ),
      ],
    ];
  }
}

class _ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ExpenseTile(this.expense, {required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final category = ExpenseCategory.byId(expense.categoryId);
    final theme = Theme.of(context);
    return Dismissible(
      key: ValueKey(expense.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onTap,
        leading: CategoryAvatar(category),
        title: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          expense.note?.isNotEmpty == true ? '${category.label} · ${expense.note}' : category.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          formatCents(expense.amountCents),
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ExpenseStore store;
  final DateTime month;
  final List<Expense> monthExpenses;

  const _SummaryCard({required this.store, required this.month, required this.monthExpenses});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = ExpenseStore.total(monthExpenses);
    final previous = ExpenseStore.total(store.forMonth(DateTime(month.year, month.month - 1)));
    final budget = store.monthlyBudgetCents;
    final top = ExpenseStore.byCategory(monthExpenses).take(3).toList();

    String? comparison;
    if (previous > 0) {
      final pct = ((total - previous) / previous * 100).round();
      comparison = pct == 0
          ? 'Igual ao mês anterior'
          : '${pct > 0 ? '+' : ''}$pct% vs. mês anterior';
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total do mês', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(
              formatCents(total),
              key: const Key('month-total'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
            if (comparison != null)
              Text(comparison, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onPrimaryContainer)),
            if (budget != null) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (total / budget).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  color: total > budget ? scheme.error : scheme.primary,
                  backgroundColor: scheme.surface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                total > budget
                    ? 'Passou ${formatCents(total - budget)} do orçamento de ${formatCents(budget)}'
                    : 'Restam ${formatCents(budget - total)} de ${formatCents(budget)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: total > budget ? scheme.error : scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (top.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final t in top)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(ExpenseCategory.byId(t.key).icon, size: 16, color: ExpenseCategory.byId(t.key).color),
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
          Text('Nenhum gasto neste mês', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Toque em "Novo gasto" para começar.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
