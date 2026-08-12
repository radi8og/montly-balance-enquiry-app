/// Represents a single income or expense entry.
///
/// [amount] is positive for income and negative for expenses — this keeps
/// balance math (`starting balance + sum of amounts`) simple everywhere else
/// in the app.
class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}
