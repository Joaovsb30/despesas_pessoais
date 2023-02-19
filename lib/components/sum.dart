import 'package:flutter/material.dart';

import '../models/transaction.dart';


class SumWeek extends StatelessWidget {
  final List<Transaction> recentTransaction;
  const SumWeek(this.recentTransaction, {Key? key}) : super(key: key);

  double get _weekTotalValue {
    double totalSum = 0.0;
    for (var i = 0; i < recentTransaction.length; i++) {
      totalSum += recentTransaction[i].value!;
    }
    return totalSum;
  }



  @override
  Widget build(BuildContext context) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Gasto total dos últimos 7 dias: R\$ ${_weekTotalValue.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),),

        ],
      );
  }
}
