import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/recurring.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class RecurringScreen extends StatelessWidget {
  final ExpenseStore store;

  const RecurringScreen({super.key, required this.store});

  Future<void> _stop(BuildContext context, RecurringRule rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Parar de repetir?'),
        content: Text('"${rule.title}" não será mais lançado nos próximos meses. '
            'Os lançamentos já criados continuam.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Parar')),
        ],
      ),
    );
    if (ok == true) await store.removeRecurring(rule);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lançamentos recorrentes')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rules = store.recurring;
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Nenhum lançamento recorrente.\n\nAo criar um gasto ou receita, escolha '
                  '"Todo mês" em Repetição (ex.: aluguel, internet, salário).',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          int sum(bool income) => rules
              .where((r) => r.isIncome == income)
              .fold(0, (total, r) => total + r.amountCents);
          final monthlyOut = sum(false);
          final monthlyIn = sum(true);
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  'Fixos por mês: gastos ${formatCents(monthlyOut)}'
                  '${monthlyIn > 0 ? ' · receitas ${formatCents(monthlyIn)}' : ''}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              for (final r in rules)
                ListTile(
                  leading: CategoryAvatar(ExpenseCategory.byId(r.categoryId)),
                  title: Text(r.title),
                  subtitle: Text('Todo dia ${r.dayOfMonth} · ${ExpenseCategory.byId(r.categoryId).label}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${r.isIncome ? '+ ' : ''}${formatCents(r.amountCents)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: r.isIncome ? incomeColor(context) : null)),
                      IconButton(
                        tooltip: 'Parar de repetir',
                        icon: const Icon(Icons.stop_circle_outlined),
                        onPressed: () => _stop(context, r),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
