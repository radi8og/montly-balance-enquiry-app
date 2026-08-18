import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../utils/currency_utils.dart';
import 'month_detail_screen.dart';

class _MonthSummary {
  final String monthKey;
  final double startingBalance;
  final double totalIncome;
  final double totalExpense;
  final List<Transaction> transactions;

  _MonthSummary({
    required this.monthKey,
    required this.startingBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.transactions,
  });

  double get netSavings => totalIncome - totalExpense;
  double get endingBalance => startingBalance + netSavings;
}

class ArchiveScreen extends StatefulWidget {
  final String currencySymbol;
  final String currentMonthKey;

  const ArchiveScreen({
    super.key,
    required this.currencySymbol,
    required this.currentMonthKey,
  });

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  final StorageService _storage = StorageService();
  bool _isLoading = true;
  List<_MonthSummary> _summaries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final balances = await _storage.getStartingBalances();
    final transactions = await _storage.getTransactions();

    final Map<String, List<Transaction>> grouped = {};
    for (final t in transactions) {
      final key = monthKeyFor(t.date);
      grouped.putIfAbsent(key, () => []).add(t);
    }

    // Every month that has either a recorded starting balance or at least
    // one transaction counts as "past" data — except the current month,
    // which is shown on the home screen instead.
    final allKeys = <String>{...balances.keys, ...grouped.keys}
      ..remove(widget.currentMonthKey);

    final summaries = allKeys.map((key) {
      final monthTransactions = grouped[key] ?? [];
      final income = monthTransactions
          .where((t) => t.amount > 0)
          .fold(0.0, (sum, t) => sum + t.amount);
      final expense = monthTransactions
          .where((t) => t.amount < 0)
          .fold(0.0, (sum, t) => sum + t.amount.abs());

      return _MonthSummary(
        monthKey: key,
        startingBalance: balances[key] ?? 0.0,
        totalIncome: income,
        totalExpense: expense,
        transactions: monthTransactions,
      );
    }).toList();

    // Reverse chronological: parse "YYYY-M" and sort descending.
    summaries.sort((a, b) {
      final aParts = a.monthKey.split('-').map(int.parse).toList();
      final bParts = b.monthKey.split('-').map(int.parse).toList();
      final aDate = DateTime(aParts[0], aParts[1]);
      final bDate = DateTime(bParts[0], bParts[1]);
      return bDate.compareTo(aDate);
    });

    setState(() {
      _summaries = summaries;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly History')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No past months yet. Once a new month begins, '
                      'previous months will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    final s = _summaries[index];
                    final saved = s.netSavings >= 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        title: Text(
                          monthKeyToLabel(s.monthKey),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Starting: ${formatMoney(widget.currencySymbol, s.startingBalance)}',
                              ),
                              Text(
                                'Income: ${formatMoney(widget.currencySymbol, s.totalIncome)}   '
                                'Expenses: ${formatMoney(widget.currencySymbol, s.totalExpense)}',
                              ),
                              Text(
                                '${saved ? 'Saved' : 'Overspent by'} '
                                '${formatMoney(widget.currencySymbol, s.netSavings.abs())} '
                                '· Ending: ${formatMoney(widget.currencySymbol, s.endingBalance)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: saved ? Colors.green[700] : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MonthDetailScreen(
                                monthKey: s.monthKey,
                                transactions: s.transactions,
                                startingBalance: s.startingBalance,
                                currencySymbol: widget.currencySymbol,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}