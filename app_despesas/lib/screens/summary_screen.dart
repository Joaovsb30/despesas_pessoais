import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class SummaryScreen extends StatefulWidget {
  final ExpenseStore store;
  final DateTime month;

  const SummaryScreen({super.key, required this.store, required this.month});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late DateTime _month = widget.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = widget.store;
    final expenses = store.forMonth(_month);
    final total = ExpenseStore.total(expenses);
    final categories = ExpenseStore.byCategory(expenses);
    final history = store.monthlyTotals(_month, 6);
    final maxMonth = history.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    final now = DateTime.now();
    final daysElapsed = monthOf(now) == _month
        ? now.day
        : DateUtils.getDaysInMonth(_month.year, _month.month);

    return Scaffold(
      appBar: AppBar(title: const Text('Resumo')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MonthSelector(month: _month, onChanged: (m) => setState(() => _month = m)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _Stat(label: 'Total', value: formatCents(total)),
                _Stat(label: 'Média/dia', value: formatCents(daysElapsed == 0 ? 0 : total ~/ daysElapsed)),
                _Stat(label: 'Gastos', value: '${expenses.length}'),
              ],
            ),
          ),
          _Section(
            title: 'Por categoria',
            child: categories.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Sem gastos neste mês.'),
                  )
                : Column(
                    children: [
                      for (final c in categories)
                        Builder(builder: (_) {
                          final cat = ExpenseCategory.byId(c.key);
                          final pct = c.value / total;
                          return ShareBar(
                            leading: CategoryAvatar(cat, radius: 16),
                            label: '${cat.label} · ${(pct * 100).toStringAsFixed(0)}%',
                            value: formatCents(c.value),
                            fraction: pct,
                            color: cat.color,
                          );
                        }),
                    ],
                  ),
          ),
          _Section(
            title: 'Últimos 6 meses',
            child: SizedBox(
              height: 180,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in history)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          FittedBox(
                            child: Text(
                              NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$').format(h.value / 100),
                              style: theme.textTheme.labelSmall,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: maxMonth == 0 ? 2 : 2 + 118 * h.value / maxMonth,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: h.key == _month
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            capitalize(DateFormat('MMM').format(h.key)).replaceAll('.', ''),
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
