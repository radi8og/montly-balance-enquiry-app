/// A template for a fixed monthly item (e.g. Rent, Salary, a subscription)
/// that automatically generates a real Transaction on the 1st of every
/// month, as long as [active] is true.
class RecurringTransaction {
  final String id;
  final String title;
  final double amount; // positive = income, negative = expense
  final String category;
  final bool active;

  RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    this.active = true,
  });

  RecurringTransaction copyWith({
    String? title,
    double? amount,
    String? category,
    bool? active,
  }) =>
      RecurringTransaction(
        id: id,
        title: title ?? this.title,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        active: active ?? this.active,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'category': category,
        'active': active,
      };

  factory RecurringTransaction.fromJson(Map<String, dynamic> json) =>
      RecurringTransaction(
        id: json['id'] as String,
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String? ?? 'Other',
        active: json['active'] as bool? ?? true,
      );
}