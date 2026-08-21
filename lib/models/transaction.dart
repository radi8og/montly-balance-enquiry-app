/// Represents a single income or expense entry.
///
/// [amount] is positive for income and negative for expenses — this keeps
/// balance math (`starting balance + sum of amounts`) simple everywhere else
/// in the app.
///
/// [category] tags the transaction (e.g. Food, Rent, Salary). Transactions
/// saved before this field existed won't have one — [fromJson] defaults
/// those to "Other" so old backups and saved data keep loading correctly.
///
/// [recurringId] is set when this transaction was auto-generated from a
/// RecurringTransaction template (e.g. monthly Rent), so the UI can mark it
/// distinctly. Null for normal manually-added transactions.
class Transaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String? recurringId;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.category = 'Other',
    this.recurringId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'category': category,
        'recurringId': recurringId,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        category: json['category'] as String? ?? 'Other',
        recurringId: json['recurringId'] as String?,
      );
}