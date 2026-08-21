import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../utils/category_utils.dart';
import '../utils/currency_utils.dart';

class _CategoryTotal {
  final String category;
  final double total;
  _CategoryTotal(this.category, this.total);
}

/// Shows where money went (or came from) in a given set of transactions,
/// as a pie chart with a matching legend. Works for the current month or
/// any archived month — it's just handed a transaction list and a title.
class CategoryBreakdownScreen extends StatefulWidget {
  final String monthLabel;
  final List<Transaction> transactions;
  final String currencySymbol;

  const CategoryBreakdownScreen({
    super.key,
    required this.monthLabel,
    required this.transactions,
    required this.currencySymbol,
  });

  @override
  State<CategoryBreakdownScreen> createState() => _CategoryBreakdownScreenState();
}

class _CategoryBreakdownScreenState extends State<CategoryBreakdownScreen> {
  bool _showExpenses = true; // toggle between Expenses and Income breakdown
  int? _touchedIndex;

  List<_CategoryTotal> get _breakdown {
    final relevant = widget.transactions.where(
      (t) => _showExpenses ? t.amount < 0 : t.amount > 0,
    );

    final Map<String, double> totals = {};
    for (final t in relevant) {
      totals.update(
        t.category,
        (existing) => existing + t.amount.abs(),
        ifAbsent: () => t.amount.abs(),
      );
    }

    final list = totals.entries
        .map((e) => _CategoryTotal(e.key, e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  double get _grandTotal => _breakdown.fold(0.0, (sum, c) => sum + c.total);

  @override
  Widget build(BuildContext context) {
    final breakdown = _breakdown;
    final total = _grandTotal;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.monthLabel} Breakdown'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Expenses')),
                ButtonSegment(value: false, label: Text('Income')),
              ],
              selected: {_showExpenses},
              onSelectionChanged: (selection) {
                setState(() {
                  _showExpenses = selection.first;
                  _touchedIndex = null;
                });
              },
            ),
          ),
          if (breakdown.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  _showExpenses
                      ? 'No expenses logged for ${widget.monthLabel}.'
                      : 'No income logged for ${widget.monthLabel}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AspectRatio(
                    aspectRatio: 1.3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: List.generate(breakdown.length, (i) {
                          final c = breakdown[i];
                          final isTouched = i == _touchedIndex;
                          final percent = total == 0 ? 0.0 : (c.total / total) * 100;
                          return PieChartSectionData(
                            color: categoryColor(c.category),
                            value: c.total,
                            title: '${percent.toStringAsFixed(0)}%',
                            radius: isTouched ? 90 : 80,
                            titleStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }),
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              _touchedIndex = response?.touchedSection?.touchedSectionIndex;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total: ${formatMoney(widget.currencySymbol, total)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(breakdown.length, (i) {
                    final c = breakdown[i];
                    final percent = total == 0 ? 0.0 : (c.total / total) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: categoryColor(c.category),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Icon(categoryIcon(c.category), size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(c.category, style: const TextStyle(fontSize: 15)),
                          ),
                          Text(
                            '${formatMoney(widget.currencySymbol, c.total)} (${percent.toStringAsFixed(0)}%)',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}