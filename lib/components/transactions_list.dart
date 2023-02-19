import 'package:flutter/material.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final void Function(String) onRemove;

  const TransactionList(this.transactions, this.onRemove, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return transactions.isEmpty ?
         LayoutBuilder(
           builder: (ctx, constraints){
             return Column(
               children: [
                 Container(
                   height: constraints.maxHeight * 0.1,
                   child: Text(
                     'Nenhuma Transação Cadastrada!',
                     style: Theme.of(context).textTheme.titleLarge
                   ),
                 ),
                 SizedBox(
                   height: constraints.maxHeight * 0.65,
                   child: Image.asset(
                     'assets/images/waiting.png',
                     fit: BoxFit.cover,
                   ),
                 ),
               ],
             );
           },
         )
        : ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (ctx, index) {
              final tr = transactions[index];
              return Card(
                elevation: 5,
                margin: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 5,
                ),
                child: GestureDetector(
                  onLongPress: (){
                    showDialog(context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Excluir transação'),
                          content: Text('Tem certeza que deseja excluir a transação "${tr.title}"?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancelar'),
                            ),
                            TextButton(onPressed: () {onRemove(tr.id!);
                              Navigator.of(ctx).pop();}, child: Text('Excluir'))
                          ],
                    ));
                  },
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple,
                      radius: 35,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: FittedBox(
                            alignment: Alignment.center,
                            fit: BoxFit.contain,
                            child: Text(
                              tr.value!.toStringAsFixed(2),
                              style:TextStyle(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      tr.title!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text(
                      DateFormat('d/MM/y').format(tr.date!),
                    ),
                    // trailing: IconButton(
                    //   icon: Icon(Icons.delete),
                    //   color: Theme.of(context).colorScheme.primary,
                    //   onPressed: () => onRemove(tr.id!),
                    // ) ,
                  ),
                ),
              );
            },
          );
  }
}
