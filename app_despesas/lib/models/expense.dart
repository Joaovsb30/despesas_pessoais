/// Um lançamento: despesa (padrão) ou receita.
class Expense {
  final int? id;
  final String title;

  /// Valor em centavos, sempre positivo. O tipo diz se entra ou sai.
  final int amountCents;
  final DateTime date;
  final String categoryId;
  final String? note;
  final bool isIncome;

  /// Regra recorrente que gerou este lançamento, se houver.
  final int? recurringId;

  Expense({
    this.id,
    required this.title,
    required this.amountCents,
    required DateTime date,
    required this.categoryId,
    this.note,
    this.isIncome = false,
    this.recurringId,
  }) : date = DateTime(date.year, date.month, date.day);

  /// Valor com sinal: negativo para despesa, positivo para receita.
  int get signedCents => isIncome ? amountCents : -amountCents;

  Expense copyWith({
    int? id,
    String? title,
    int? amountCents,
    DateTime? date,
    String? categoryId,
    String? note,
    bool? isIncome,
    int? recurringId,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
      isIncome: isIncome ?? this.isIncome,
      recurringId: recurringId ?? this.recurringId,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount_cents': amountCents,
        'date': date.millisecondsSinceEpoch,
        'category': categoryId,
        'note': note,
        'type': isIncome ? 'income' : 'expense',
        'recurring_id': recurringId,
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int?,
        title: map['title'] as String,
        amountCents: map['amount_cents'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        categoryId: map['category'] as String,
        note: map['note'] as String?,
        isIncome: map['type'] == 'income',
        recurringId: map['recurring_id'] as int?,
      );
}
