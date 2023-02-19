import 'package:expenses/components/sum.dart';
import 'components/chart.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'components/transaction_form.dart';
import 'components/transactions_list.dart';
import 'models/transactionApp.dart';

void main() {

  runApp(ExpensesApp());}


class ExpensesApp extends StatelessWidget {
  const ExpensesApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MyHomePage(),
        theme: ThemeData(
        primaryColor: Colors.purple,
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.amber,
        background: Colors.purple,
        primary: Colors.purple,
        )
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<TransactionApp> _transactions = [];
  bool _showChart = false;

  List<TransactionApp> get _recentTransactions {
    return _transactions.where((tr){
      return tr.date!.isAfter(DateTime.now().subtract(Duration(days: 7)));
    }).toList();
  }

  _addTransaction(String title, double value, DateTime date) {
    final newTransaction = TransactionApp(
      id: Random().nextDouble().toString(),
      date: date,
      title: title,
      value: value,
    );

    setState(() {
      _transactions.add(newTransaction);
    });
    Navigator.of(context).pop();
  }

  _removeTransaction(String id){
    setState(() {
      _transactions.removeWhere((tr) => tr.id == id);
    });
  }

  _openTransactionFormModal(BuildContext context){
    showModalBottomSheet(
        context: context,
        builder: (_){
          return TransactionForm(_addTransaction);
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final appBar = AppBar(
      backgroundColor: Theme.of(context).colorScheme.background,
      title: Text('Gastomêtro',
      style: TextStyle(fontSize: 18 * MediaQuery.of(context).textScaleFactor),
      ),
      actions: [
        if(isLandscape)IconButton(onPressed: () {
          setState(() {
            _showChart = !_showChart;
          });
        },
            icon: _showChart ? Icon(Icons.list) : Icon(Icons.bar_chart_outlined) ),
        IconButton(onPressed: () => _openTransactionFormModal(context),
            icon: Icon(Icons.add))
      ],
    );
    final availableHeight = MediaQuery.of(context).size.height - appBar.preferredSize.height
        - MediaQuery.of(context).padding.top;

    return Scaffold(
      appBar: appBar,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            //if(isLandscape)
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   children: [
            //     Text('Exibir Gráfico'),
            //     // Switch(
            //     //     value: _showChart,
            //     //     onChanged: (value){
            //     //       setState(() {
            //     //         _showChart = value;
            //     //       });
            //     //
            //     //     }),
            //   ],
            // ),
            if(_showChart || !isLandscape)
            Container(
              height: availableHeight * (isLandscape ? 0.5 : 0.25),
              child: Chart(_recentTransactions),
            ),
            if(!_showChart || !isLandscape)
              Container(
                  height: availableHeight * 0.05,
                  child: SumWeek(_recentTransactions)),
            if(!_showChart || !isLandscape)
            Container(
              height: availableHeight * 0.70,
                child: TransactionList(_transactions, _removeTransaction)
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => _openTransactionFormModal(context) ,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
