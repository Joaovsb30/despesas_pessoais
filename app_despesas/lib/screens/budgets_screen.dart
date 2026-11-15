import 'package:flutter/material.dart';

import '../models/category.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

/// Orçamento geral e limites por categoria, com o andamento do mês atual.
class BudgetsScreen extends StatelessWidget {
  final ExpenseStore store;

  const BudgetsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final theme = Theme.of(context);
          final month = monthOf(DateTime.now());
          final items = store.forMonth(month);
          final spentByCat = Map.fromEntries(ExpenseStore.byCategory(items));
          final spent = ExpenseStore.total(ExpenseStore.onlyExpenses(items));
          final budget = store.monthlyBudgetCents;
          final limits = store.categoryBudgets;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('${monthLabel(month)} · toque para definir o limite',
                    style: theme.textTheme.bodySmall),
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.savings)),
                title: const Text('Orçamento geral do mês'),
                subtitle: _progress(context, spent, budget),
                trailing: Text(budget == null ? 'Definir' : formatCents(budget)),
                onTap: () => showMoneyDialog(
                  context,
                  title: 'Orçamento geral do mês',
                  initialCents: budget,
                  onSave: store.setMonthlyBudget,
                ),
              ),
              const Divider(),
              for (final c in ExpenseCategory.expenses)
                ListTile(
                  leading: CategoryAvatar(c),
                  title: Text(c.label),
                  subtitle: _progress(context, spentByCat[c.id] ?? 0, limits[c.id]),
                  trailing: Text(limits[c.id] == null ? 'Sem limite' : formatCents(limits[c.id]!)),
                  onTap: () => showMoneyDialog(
                    context,
                    title: 'Limite para ${c.label}',
                    initialCents: limits[c.id],
                    onSave: (cents) => store.setCategoryBudget(c.id, cents),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _progress(BuildContext context, int spent, int? limit) {
    final scheme = Theme.of(context).colorScheme;
    if (limit == null) return Text('Gasto no mês: ${formatCents(spent)}');
    final over = spent > limit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (spent / limit).clamp(0, 1).toDouble(),
            minHeight: 6,
            color: over ? scheme.error : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          over ? 'Passou ${formatCents(spent - limit)}' : '${formatCents(spent)} · restam ${formatCents(limit - spent)}',
          style: TextStyle(color: over ? scheme.error : null),
        ),
      ],
    );
  }
}
