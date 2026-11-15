import 'package:flutter/cupertino.dart';
class TransactionApp{
  final String? id;
  final String? title;
  final double? value;
  final DateTime? date;

  TransactionApp({
   @required this.id,
   @required this.title,
   @required this.value,
   @required this.date
  });
}