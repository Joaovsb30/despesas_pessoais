import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

String formatCents(int cents) => _currency.format(cents / 100);

/// Aceita "12,50", "12.50", "1.234,56", "R$ 30" etc. Retorna centavos ou null.
int? parseMoney(String input) {
  var s = input.replaceAll('R\$', '').replaceAll(RegExp(r'\s'), '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    // "1.234" no padrão brasileiro = mil duzentos e trinta e quatro
    s = s.replaceAll('.', '');
  }
  final value = double.tryParse(s);
  if (value == null || value.isNaN || value.isInfinite) return null;
  return (value * 100).round();
}

/// Formata centavos para edição no campo de texto: 1234 -> "12,34".
String centsToInput(int cents) =>
    (cents / 100).toStringAsFixed(2).replaceAll('.', ',');
