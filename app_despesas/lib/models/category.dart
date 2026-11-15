import 'package:flutter/material.dart';

class ExpenseCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  const ExpenseCategory(this.id, this.label, this.icon, this.color);

  static const List<ExpenseCategory> all = [
    ExpenseCategory('alimentacao', 'Alimentação', Icons.restaurant, Color(0xFFE76F51)),
    ExpenseCategory('mercado', 'Mercado', Icons.shopping_cart, Color(0xFF2A9D8F)),
    ExpenseCategory('transporte', 'Transporte', Icons.directions_car, Color(0xFF457B9D)),
    ExpenseCategory('moradia', 'Moradia', Icons.home, Color(0xFF8D6E63)),
    ExpenseCategory('contas', 'Contas', Icons.receipt_long, Color(0xFF6D597A)),
    ExpenseCategory('saude', 'Saúde', Icons.favorite, Color(0xFFD62839)),
    ExpenseCategory('lazer', 'Lazer', Icons.celebration, Color(0xFFF4A261)),
    ExpenseCategory('educacao', 'Educação', Icons.school, Color(0xFF3A86FF)),
    ExpenseCategory('compras', 'Compras', Icons.shopping_bag, Color(0xFFB5179E)),
    ExpenseCategory('outros', 'Outros', Icons.more_horiz, Color(0xFF6C757D)),
  ];

  static ExpenseCategory byId(String id) =>
      all.firstWhere((c) => c.id == id, orElse: () => all.last);
}
