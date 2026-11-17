import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'data/expense_repository.dart';
import 'receipts/receipt_service.dart';
import 'screens/home_screen.dart';
import 'state/expense_store.dart';
import 'utils/app_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'pt_BR';
  await initializeDateFormatting('pt_BR');
  final store = ExpenseStore(SqfliteExpenseRepository());
  runApp(ExpensesApp(
    store: store,
    receiptReader: OnDeviceReceiptReader(),
    receiptInbox: ShareIntentInbox(),
  ));
  await store.load();
}

class ExpensesApp extends StatelessWidget {
  final ExpenseStore store;
  final DeviceAuth? auth;
  final ReceiptReader? receiptReader;
  final ReceiptInbox? receiptInbox;

  const ExpensesApp({super.key, required this.store, this.auth, this.receiptReader, this.receiptInbox});

  ThemeData _theme(Brightness brightness) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: brightness,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Despesas',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeScreen(store: store, receiptReader: receiptReader, receiptInbox: receiptInbox),
      // Fica acima do Navigator para cobrir todas as telas quando bloqueado.
      builder: (context, child) =>
          LockGate(store: store, auth: auth ?? DeviceAuth(), child: child!),
    );
  }
}
