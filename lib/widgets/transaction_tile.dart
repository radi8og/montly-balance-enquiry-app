import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../theme/app_colors.dart';
import '../utils/currency_utils.dart';

/// A single transaction row, reused by both the current-month (interactive)
/// view and the archived-month (read-only) view.
///
/// When [readOnly] is true, tapping and swipe-to-delete are disabled
/// entirely — archived months are historical record, not editable data.
class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final String currencySymbol;
  final bool readOnly;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.currencySymbol,
    this.readOnly = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.amount < 0;

    final tile = ListTile(
      onTap: readOnly ? null : onTap,
      leading: Icon(
        isExpense ? Icons.arrow_downward : Icons.arrow_upward,
        color: isExpense ? AppColors.expense : AppColors.income,
      ),
      title: Text(transaction.title),
      subtitle: Text(
        '${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${isExpense ? '-' : '+'}${formatMoney(currencySymbol, transaction.amount.abs())}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isExpense ? AppColors.expense : AppColors.income,
            ),
          ),
          if (!readOnly)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.grey,
              onPressed: onDelete,
              tooltip: 'Delete',
            ),
        ],
      ),
    );

    if (readOnly || onDelete == null) return tile;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: AppColors.expense,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete?.call(); // the callback is expected to show its own confirm dialog
        return false;
      },
      child: tile,
    );
  }
}