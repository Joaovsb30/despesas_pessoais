import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';
import '../widgets/common.dart';

class SearchScreen extends StatefulWidget {
  final ExpenseStore store;
  final Future<void> Function(Expense) onOpen;

  const SearchScreen({super.key, required this.store, required this.onOpen});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _query,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Buscar descrição, categoria...', border: InputBorder.none),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          if (_query.text.isNotEmpty)
            IconButton(
              tooltip: 'Limpar',
              icon: const Icon(Icons.close),
              onPressed: () => setState(_query.clear),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) {
          final results = widget.store.search(_query.text);
          if (_query.text.trim().isEmpty) {
            return const Center(child: Text('Digite para buscar em todos os meses.'));
          }
          if (results.isEmpty) {
            return const Center(child: Text('Nada encontrado.'));
          }
          final spent = ExpenseStore.total(ExpenseStore.onlyExpenses(results));
          final income = ExpenseStore.total(ExpenseStore.onlyIncome(results));
          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  '${results.length} lançamento${results.length == 1 ? '' : 's'} · '
                  'gastos ${formatCents(spent)}${income > 0 ? ' · receitas ${formatCents(income)}' : ''}',
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
              for (final e in results) ExpenseTile(e, showDate: true, onTap: () => widget.onOpen(e)),
            ],
          );
        },
      ),
    );
  }
}
