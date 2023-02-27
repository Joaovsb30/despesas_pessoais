import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';



class AdaptativeTextField extends StatelessWidget {
  final TextEditingController? controller;
  final Function? onSubmited;
  final bool? decimalChange;
  final String? labelText;

  AdaptativeTextField({required this.controller, required this.onSubmited, required this.decimalChange, required this.labelText});

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ?

    CupertinoTextField(
      keyboardType: TextInputType.numberWithOptions(decimal: decimalChange),
      onSubmitted: (_) => onSubmited!(),
      controller: controller,
      placeholder: labelText,
    ) :

    TextField(
      keyboardType: TextInputType.numberWithOptions(decimal: decimalChange),
      controller: controller!,
      onSubmitted: (_) => onSubmited!(),
      decoration: InputDecoration(labelText: labelText),
    );
  }
}
