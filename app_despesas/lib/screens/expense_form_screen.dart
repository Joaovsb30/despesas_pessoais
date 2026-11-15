import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/expense.dart';
import '../state/expense_store.dart';
import '../utils/money.dart';

enum Repeat { none, monthly, installments }

class ExpenseFormScreen extends StatefulWidget {
  final ExpenseStore store;
  final Expense? expense;
  final DateTime initialDate;

  const ExpenseFormScreen({
    super.key,
    required this.store,
    this.expense,
    required this.initialDate,
  });

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  final _installments = TextEditingController(text: '2');
  late DateTime _date;
  late String _categoryId;
  late bool _isIncome;
  Repeat _repeat = Repeat.none;
  bool _saving = false;

  bool get _editing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    _title = TextEditingController(text: e?.title ?? '');
    _amount = TextEditingController(text: e == null ? '' : centsToInput(e.amountCents));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? widget.initialDate;
    _isIncome = e?.isIncome ?? false;
    _categoryId = e?.categoryId ?? ExpenseCategory.forType(income: _isIncome).first.id;
    _amount.addListener(() => setState(() {}));
    _installments.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    _installments.dispose();
    super.dispose();
  }

  void _setType(bool income) {
    if (income == _isIncome) return;
    setState(() {
      _isIncome = income;
      _categoryId = ExpenseCategory.forType(income: income).first.id;
      if (income && _repeat == Repeat.installments) _repeat = Repeat.none;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  int? get _installmentCount {
    final n = int.tryParse(_installments.text.trim());
    return n != null && n >= 2 && n <= 120 ? n : null;
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final note = _note.text.trim();
    final expense = Expense(
      id: widget.expense?.id,
      title: _title.text.trim(),
      amountCents: parseMoney(_amount.text)!,
      date: _date,
      categoryId: _categoryId,
      note: note.isEmpty ? null : note,
      isIncome: _isIncome,
      recurringId: widget.expense?.recurringId,
    );
    final store = widget.store;
    if (_editing) {
      await store.update(expense);
    } else {
      switch (_repeat) {
        case Repeat.none:
          await store.add(expense);
        case Repeat.monthly:
          await store.addRecurring(expense);
        case Repeat.installments:
          await store.addInstallments(expense, _installmentCount!);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir lançamento?'),
        content: Text('"${widget.expense!.title}" será apagado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.store.remove(widget.expense!);
    if (mounted) Navigator.of(context).pop();
  }

  String? get _installmentPreview {
    final cents = parseMoney(_amount.text);
    final n = _installmentCount;
    if (cents == null || cents <= 0 || n == null) return null;
    return '$n× de ${formatCents(cents ~/ n)} · total ${formatCents(cents)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = _isIncome ? 'receita' : 'gasto';
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Editar $kind' : (_isIncome ? 'Nova receita' : 'Novo gasto')),
        actions: [
          if (_editing)
            IconButton(tooltip: 'Excluir', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Despesa'), icon: Icon(Icons.arrow_downward)),
                ButtonSegment(value: true, label: Text('Receita'), icon: Icon(Icons.arrow_upward)),
              ],
              selected: {_isIncome},
              onSelectionChanged: (s) => _setType(s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: !_editing,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: theme.textTheme.headlineSmall,
              decoration: InputDecoration(
                labelText: _repeat == Repeat.installments ? 'Valor total' : 'Valor',
                prefixText: 'R\$ ',
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final cents = parseMoney(v ?? '');
                if (cents == null) return 'Informe um valor válido';
                if (cents <= 0) return 'O valor precisa ser maior que zero';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Descrição',
                hintText: _isIncome ? 'Ex.: Salário, Pix do João...' : 'Ex.: Almoço, Uber, Luz...',
                border: const OutlineInputBorder(),
              ),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Informe uma descrição' : null,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_repeat == Repeat.none ? 'Data' : 'Primeira data'),
              subtitle: Text(DateFormat("EEEE, d 'de' MMMM 'de' y").format(_date)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            const SizedBox(height: 8),
            Text('Categoria', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in ExpenseCategory.forType(income: _isIncome))
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(c.icon, size: 18, color: c.color),
                    label: Text(c.label),
                    selected: _categoryId == c.id,
                    onSelected: (_) => setState(() => _categoryId = c.id),
                  ),
              ],
            ),
            if (!_editing) ...[
              const SizedBox(height: 20),
              Text('Repetição', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Não repete'),
                    selected: _repeat == Repeat.none,
                    onSelected: (_) => setState(() => _repeat = Repeat.none),
                  ),
                  ChoiceChip(
                    avatar: const Icon(Icons.autorenew, size: 18),
                    label: const Text('Todo mês'),
                    selected: _repeat == Repeat.monthly,
                    onSelected: (_) => setState(() => _repeat = Repeat.monthly),
                  ),
                  if (!_isIncome)
                    ChoiceChip(
                      avatar: const Icon(Icons.credit_card, size: 18),
                      label: const Text('Parcelado'),
                      selected: _repeat == Repeat.installments,
                      onSelected: (_) => setState(() => _repeat = Repeat.installments),
                    ),
                ],
              ),
              if (_repeat == Repeat.monthly)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Será lançado automaticamente todo dia ${_date.day}. '
                    'Para parar, vá em Mais → Lançamentos recorrentes.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              if (_repeat == Repeat.installments) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _installments,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Número de parcelas',
                    border: const OutlineInputBorder(),
                    helperText: _installmentPreview,
                  ),
                  validator: (_) => _installmentCount == null ? 'Entre 2 e 120 parcelas' : null,
                ),
              ],
            ],
            if (_editing && widget.expense!.recurringId != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Lançamento recorrente: alterar aqui muda só este mês.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + MediaQuery.viewInsetsOf(context).bottom),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_editing ? 'Salvar alterações' : (_isIncome ? 'Adicionar receita' : 'Adicionar gasto')),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ),
      ),
    );
  }
}
