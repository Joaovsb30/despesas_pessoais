import 'package:flutter/material.dart';

class ChartBar extends StatelessWidget {
  final String? label;
  final double? value;
  final double? percentage;

   ChartBar({
    this.label,
    this.value,
    this.percentage,
    Key? key,
  }) : super(key: key);

  final tema = ThemeData();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (ctx, constrainsts) {
          return Column(
            children: [
              Container(
                height: constrainsts.maxHeight * 0.15,
                child: FittedBox(
                    child: Text('R\$ ${value!.toStringAsFixed(0)}')
                ),
              ),
              SizedBox(height: constrainsts.maxHeight * 0.05,),
              Container(
                  height: constrainsts.maxHeight * 0.6,
                  width: 10,
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: Colors.grey,
                                width: 1.0
                            ),
                            color: Color.fromRGBO(220, 220, 200, 1),
                            borderRadius: BorderRadius.circular(5)
                        ),
                      ),
                      FractionallySizedBox(
                        heightFactor: percentage,
                        child: Container(
                          decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(5)
                          ),
                        ),
                      )
                    ],
                  )
              ),
              SizedBox(height: constrainsts.maxHeight * 0.05),
              Container(
                height: constrainsts.maxHeight * 0.15,
                  child: FittedBox(
                      child: Text(label!
                      ))
              ),
            ],
          );
        }
    );
  }
}
