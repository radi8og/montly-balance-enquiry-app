import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/csv_service.dart';
import '../utils/currency_utils.dart';
import '../widgets/month_summary_card.dart';
import '../widgets/transaction_tile.dart';

/// Read-only view of a single archived (past) month. No adding, editing,
/// or deleting — this is historical record.
class MonthDetailScreen extends StatelessWidget {
  final String monthKey;
  final List<Transaction> transactions;
  final double startingBalance;
  final String currencySymbol;

  const MonthDetailScreen({
    super.key,
    required this.monthKey,
    required this.transactions,
    required this.startingBalance,
    required this.currencySymbol,
  });

  double get _netForMonth => transactions.fold(0.0, (sum, t) => sum + t.amount);
  double get _endingBalance => startingBalance + _netForMonth;

  List<Transaction> get _sortedTransactions {
    final list = List<Transaction>.from(transactions);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> _exportCsv(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await CsvService.exportAndShare(
        monthKey: monthKey,
        transactions: transactions,
        startingBalance: startingBalance,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(monthKeyToLabel(monthKey)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export Month to CSV',
            onPressed: () => _exportCsv(context),
          ),
        ],
      ),
      body: Column(
        children: [
          MonthSummaryCard(
            balance: _endingBalance,
            netForMonth: _netForMonth,
            currencySymbol: currencySymbol,
            balanceLabel: 'Ending Balance',
            netLabel: 'Net savings',
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Read-only archive — this month can no longer be edited.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
          Expanded(
            child: _sortedTransactions.isEmpty
                ? const Center(
                    child: Text(
                      'No transactions were logged this month.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _sortedTransactions.length,
                    itemBuilder: (context, index) => TransactionTile(
                      transaction: _sortedTransactions[index],
                      currencySymbol: currencySymbol,
                      readOnly: true,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}