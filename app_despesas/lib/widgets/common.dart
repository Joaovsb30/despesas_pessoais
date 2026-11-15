import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../utils/money.dart';

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String monthLabel(DateTime month) =>
    capitalize(DateFormat("MMMM 'de' y").format(month));

class CategoryAvatar extends StatelessWidget {
  final ExpenseCategory category;
  final double radius;

  const CategoryAvatar(this.category, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: category.color.withValues(alpha: 0.18),
      child: Icon(category.icon, color: category.color, size: radius),
    );
  }
}

class MonthSelector extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;

  const MonthSelector({super.key, required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrent = month.year == now.year && month.month == now.month;
    return Row(
      children: [
        IconButton(
          tooltip: 'Mês anterior',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        ),
        Expanded(
          child: TextButton(
            onPressed: isCurrent
                ? null
                : () => onChanged(DateTime(now.year, now.month)),
            child: Text(
              monthLabel(month),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(DateTime(month.year, month.month + 1)),
        ),
      ],
    );
  }
}

/// Barra horizontal simples: rótulo, valor e proporção.
class ShareBar extends StatelessWidget {
  final Widget leading;
  final String label;
  final String value;
  final double fraction;
  final Color color;

  const ShareBar({
    super.key,
    required this.leading,
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                    Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0, 1),
                    minHeight: 6,
                    color: color,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Linha de um lançamento. Receitas aparecem em verde com "+".
class ExpenseTile extends StatelessWidget {
  final Expense expense;
  final VoidCallback onTap;
  final bool showDate;

  const ExpenseTile(this.expense, {super.key, required this.onTap, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final category = ExpenseCategory.byId(expense.categoryId);
    final theme = Theme.of(context);
    final parts = [
      if (showDate) DateFormat('dd/MM/yy').format(expense.date),
      category.label,
      if (expense.note?.isNotEmpty == true) expense.note!,
    ];
    return ListTile(
      onTap: onTap,
      leading: CategoryAvatar(category),
      title: Row(
        children: [
          Flexible(child: Text(expense.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (expense.recurringId != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.autorenew, size: 14, color: theme.colorScheme.outline),
          ],
        ],
      ),
      subtitle: Text(parts.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        '${expense.isIncome ? '+ ' : ''}${formatCents(expense.amountCents)}',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: expense.isIncome ? incomeColor(context) : null,
        ),
      ),
    );
  }
}

Color incomeColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);

/// Pede um valor em reais. Retorna centavos, null para "remover", ou cancela (sem chamar [onSave]).
Future<void> showMoneyDialog(
  BuildContext context, {
  required String title,
  int? initialCents,
  String helper = 'Deixe vazio para remover',
  required Future<void> Function(int? cents) onSave,
}) async {
  final controller = TextEditingController(text: initialCents == null ? '' : centsToInput(initialCents));
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(prefixText: 'R\$ ', hintText: 'Ex.: 500,00', helperText: helper),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Salvar')),
      ],
    ),
  );
  if (result == null) return;
  final cents = parseMoney(result);
  await onSave(cents != null && cents > 0 ? cents : null);
}
