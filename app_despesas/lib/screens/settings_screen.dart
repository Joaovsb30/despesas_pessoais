import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../state/expense_store.dart';
import '../utils/app_lock.dart';
import '../utils/csv_export.dart';
import 'budgets_screen.dart';
import 'recurring_screen.dart';

class SettingsScreen extends StatelessWidget {
  final ExpenseStore store;
  final DeviceAuth? auth;

  const SettingsScreen({super.key, required this.store, this.auth});

  void _snack(BuildContext context, String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _toggleLock(BuildContext context, bool enable) async {
    final auth = this.auth ?? DeviceAuth();
    if (enable && !await auth.isAvailable()) {
      if (context.mounted) {
        _snack(context, 'Configure uma digital, rosto ou PIN no celular para usar o bloqueio.');
      }
      return;
    }
    final ok = await auth.authenticate(enable ? 'Confirme para ativar o bloqueio' : 'Confirme para desativar o bloqueio');
    if (!ok) return;
    await store.setLockEnabled(enable);
  }

  Future<void> _export(BuildContext context) async {
    if (store.expenses.isEmpty) {
      _snack(context, 'Nenhum lançamento para exportar.');
      return;
    }
    await shareCsv(store.expenses);
  }

  Future<void> _import(BuildContext context) async {
    final files = await FilePicker.pickFiles(type: FileType.any);
    if (files.isEmpty) return;
    final CsvImportResult parsed;
    try {
      parsed = expensesFromCsv(await files.first.xFile.readAsString());
    } catch (_) {
      if (context.mounted) _snack(context, 'Não consegui ler esse arquivo. Escolha um CSV exportado pelo app.');
      return;
    }
    if (!context.mounted) return;
    if (parsed.expenses.isEmpty) {
      _snack(context, 'Nenhum lançamento válido encontrado no arquivo.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar backup?'),
        content: Text(
          '${parsed.expenses.length} lançamentos serão adicionados aos que já existem.'
          '${parsed.skipped > 0 ? '\n${parsed.skipped} linhas inválidas serão ignoradas.' : ''}'
          '\n\nSe você importar o mesmo arquivo duas vezes, os lançamentos ficarão duplicados.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar')),
        ],
      ),
    );
    if (ok != true) return;
    await store.addAll(parsed.expenses);
    if (context.mounted) _snack(context, '${parsed.expenses.length} lançamentos importados.');
  }

  @override
  Widget build(BuildContext context) {
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Scaffold(
      appBar: AppBar(title: const Text('Mais')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.savings),
              title: const Text('Orçamentos'),
              subtitle: const Text('Limite do mês e por categoria'),
              onTap: () => push(BudgetsScreen(store: store)),
            ),
            ListTile(
              leading: const Icon(Icons.autorenew),
              title: const Text('Lançamentos recorrentes'),
              subtitle: Text(store.recurring.isEmpty
                  ? 'Contas fixas, assinaturas, salário'
                  : '${store.recurring.length} ativo${store.recurring.length == 1 ? '' : 's'}'),
              onTap: () => push(RecurringScreen(store: store)),
            ),
            const Divider(),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: const Text('Bloquear com digital/PIN'),
              subtitle: const Text('Pede desbloqueio ao abrir o app'),
              value: store.lockEnabled,
              onChanged: (v) => _toggleLock(context, v),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Exportar backup (CSV)'),
              subtitle: const Text('Salve no Drive, e-mail ou abra no Excel'),
              onTap: () => _export(context),
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('Importar backup (CSV)'),
              subtitle: const Text('Restaura lançamentos de um CSV exportado'),
              onTap: () => _import(context),
            ),
          ],
        ),
      ),
    );
  }
}
