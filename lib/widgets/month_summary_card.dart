import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/currency_utils.dart';

/// The teal balance card shown at the top of both the current-month screen
/// and each archived month's read-only detail screen.
class MonthSummaryCard extends StatelessWidget {
  final double balance;
  final double netForMonth;
  final String currencySymbol;
  final String balanceLabel;
  final String netLabel;

  const MonthSummaryCard({
    super.key,
    required this.balance,
    required this.netForMonth,
    required this.currencySymbol,
    this.balanceLabel = 'Current Balance',
    this.netLabel = 'This month',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Column(
        children: [
          Text(balanceLabel, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            formatMoney(currencySymbol, balance),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$netLabel: ${netForMonth >= 0 ? '+' : ''}${formatMoney(currencySymbol, netForMonth)}',
            style: TextStyle(
              fontSize: 14,
              color: netForMonth >= 0
                  ? AppColors.incomeText(context)
                  : AppColors.expenseText(context),
            ),
          ),
        ],
      ),
    );
  }
}