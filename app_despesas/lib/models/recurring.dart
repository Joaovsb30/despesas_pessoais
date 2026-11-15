/// Lançamento que se repete todo mês (aluguel, assinatura, salário...).
class RecurringRule {
  final int? id;
  final String title;
  final int amountCents;
  final String categoryId;
  final bool isIncome;
  final String? note;

  /// Dia do mês em que o lançamento cai (ajustado para o último dia em meses curtos).
  final int dayOfMonth;

  /// Último mês (dia 1) para o qual o lançamento já foi criado.
  final DateTime lastGeneratedMonth;

  RecurringRule({
    this.id,
    required this.title,
    required this.amountCents,
    required this.categoryId,
    required this.isIncome,
    this.note,
    required this.dayOfMonth,
    required DateTime lastGeneratedMonth,
  }) : lastGeneratedMonth = DateTime(lastGeneratedMonth.year, lastGeneratedMonth.month);

  RecurringRule copyWith({int? id, DateTime? lastGeneratedMonth}) => RecurringRule(
        id: id ?? this.id,
        title: title,
        amountCents: amountCents,
        categoryId: categoryId,
        isIncome: isIncome,
        note: note,
        dayOfMonth: dayOfMonth,
        lastGeneratedMonth: lastGeneratedMonth ?? this.lastGeneratedMonth,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount_cents': amountCents,
        'category': categoryId,
        'type': isIncome ? 'income' : 'expense',
        'note': note,
        'day_of_month': dayOfMonth,
        'last_generated': lastGeneratedMonth.millisecondsSinceEpoch,
      };

  factory RecurringRule.fromMap(Map<String, Object?> m) => RecurringRule(
        id: m['id'] as int?,
        title: m['title'] as String,
        amountCents: m['amount_cents'] as int,
        categoryId: m['category'] as String,
        isIncome: m['type'] == 'income',
        note: m['note'] as String?,
        dayOfMonth: m['day_of_month'] as int,
        lastGeneratedMonth: DateTime.fromMillisecondsSinceEpoch(m['last_generated'] as int),
      );
}
