import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final bool isIncome;

  const ExpenseCategory(this.id, this.label, this.icon, this.color, {this.isIncome = false});

  static const List<ExpenseCategory> expenses = [
    ExpenseCategory('alimentacao', 'Alimentação', Icons.restaurant, Color(0xFFE76F51)),
    ExpenseCategory('mercado', 'Mercado', Icons.shopping_cart, Color(0xFF2A9D8F)),
    ExpenseCategory('transporte', 'Transporte', Icons.directions_car, Color(0xFF457B9D)),
    ExpenseCategory('moradia', 'Moradia', Icons.home, Color(0xFF8D6E63)),
    ExpenseCategory('contas', 'Contas', Icons.receipt_long, Color(0xFF6D597A)),
    ExpenseCategory('saude', 'Saúde', Icons.favorite, Color(0xFFD62839)),
    ExpenseCategory('lazer', 'Lazer', Icons.celebration, Color(0xFFF4A261)),
    ExpenseCategory('educacao', 'Educação', Icons.school, Color(0xFF3A86FF)),
    ExpenseCategory('compras', 'Compras', Icons.shopping_bag, Color(0xFFB5179E)),
    ExpenseCategory('assinaturas', 'Assinaturas', Icons.subscriptions, Color(0xFF7B2CBF)),
    ExpenseCategory('outros', 'Outros', Icons.more_horiz, Color(0xFF6C757D)),
  ];

  static const List<ExpenseCategory> incomes = [
    ExpenseCategory('salario', 'Salário', Icons.work, Color(0xFF2E7D32), isIncome: true),
    ExpenseCategory('freelance', 'Freelance', Icons.laptop_mac, Color(0xFF00897B), isIncome: true),
    ExpenseCategory('investimentos', 'Investimentos', Icons.trending_up, Color(0xFF1565C0), isIncome: true),
    ExpenseCategory('presente', 'Presente', Icons.card_giftcard, Color(0xFFC2185B), isIncome: true),
    ExpenseCategory('outras_receitas', 'Outras receitas', Icons.attach_money, Color(0xFF558B2F), isIncome: true),
  ];

  static const List<ExpenseCategory> all = [...expenses, ...incomes];

  static List<ExpenseCategory> forType({required bool income}) => income ? incomes : expenses;

  static ExpenseCategory byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => expenses.last);

  /// Usado na importação do CSV, que guarda o nome da categoria.
  static ExpenseCategory byLabel(String label, {required bool income}) {
    final normalized = label.trim().toLowerCase();
    return forType(income: income).firstWhere(
      (c) => c.label.toLowerCase() == normalized,
      orElse: () => forType(income: income).last,
    );
  }
}
