class Expense {
  final int? id;
  final String title;

  /// Valor em centavos, para evitar erro de arredondamento com double.
  final int amountCents;
  final DateTime date;
  final String categoryId;
  final String? note;

  Expense({
    this.id,
    required this.title,
    required this.amountCents,
    required DateTime date,
    required this.categoryId,
    this.note,
  }) : date = DateTime(date.year, date.month, date.day);

  Expense copyWith({
    int? id,
    String? title,
    int? amountCents,
    DateTime? date,
    String? categoryId,
    String? note,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      note: note ?? this.note,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'amount_cents': amountCents,
        'date': date.millisecondsSinceEpoch,
        'category': categoryId,
        'note': note,
      };

  factory Expense.fromMap(Map<String, Object?> map) => Expense(
        id: map['id'] as int?,
        title: map['title'] as String,
        amountCents: map['amount_cents'] as int,
        date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
        categoryId: map['category'] as String,
        note: map['note'] as String?,
      );
}
