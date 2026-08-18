import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';

/// Builds a CSV export for a single month's transactions and hands it to
/// the native share sheet via share_plus.
class CsvService {
  CsvService._();

  /// Columns: ID, Date, Title, Type, Amount, Balance After Transaction.
  /// The running balance column is computed chronologically, starting from
  /// that month's starting balance — so it reflects the balance as it
  /// actually progressed through the month, not just a snapshot.
  static String buildCsv({
    required List<Transaction> transactions,
    required double startingBalance,
  }) {
    final sorted = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Title,Type,Amount,Balance After Transaction');

    double running = startingBalance;
    for (final t in sorted) {
      running += t.amount;
      final type = t.amount < 0 ? 'Expense' : 'Income';
      final amountStr = t.amount.abs().toStringAsFixed(2);
      final dateStr = _formatDate(t.date);
      final safeTitle = t.title.replaceAll('"', '""');
      buffer.writeln(
          '${t.id},$dateStr,"$safeTitle",$type,$amountStr,${running.toStringAsFixed(2)}');
    }

    return buffer.toString();
  }

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Writes the CSV to a temporary file named MonoBal_[YYYY-MM].csv and
  /// opens the native share sheet. Throws on failure — callers should wrap
  /// this in a try/catch and show a SnackBar.
  static Future<void> exportAndShare({
    required String monthKey,
    required List<Transaction> transactions,
    required double startingBalance,
  }) async {
    final csv = buildCsv(
      transactions: transactions,
      startingBalance: startingBalance,
    );

    final dir = await getTemporaryDirectory();
    final filename = 'MonoBal_${paddedMonthKey(monthKey)}.csv';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'MonoBal export — ${monthKeyToLabel(monthKey)}',
    );
  }
}