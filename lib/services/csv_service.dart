import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/transaction.dart';
import '../utils/currency_utils.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Builds a CSV export for a single month's transactions and saves/shares
/// it depending on platform.
///
/// share_plus's file-attachment support on Windows/Linux desktop is
/// unreliable (it can silently drop the file and only pass through the
/// share text), so desktop platforms use file_picker's native "Save As"
/// dialog instead — writing the CSV directly to a location the user picks.
/// Mobile (Android/iOS) keeps using the native share sheet, which works
/// reliably there.
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

  /// Returns a short human-readable result string on success (e.g. the
  /// saved file path on desktop, or null on mobile since the share sheet
  /// handles the rest). Returns null if the user cancelled a desktop save
  /// dialog. Throws on failure — callers should wrap this in a try/catch
  /// and show a SnackBar.
  static Future<String?> exportAndShare({
    required String monthKey,
    required List<Transaction> transactions,
    required double startingBalance,
  }) async {
    final csv = buildCsv(
      transactions: transactions,
      startingBalance: startingBalance,
    );
    final filename = 'MonoBal_${paddedMonthKey(monthKey)}.csv';

    if (_isDesktop) {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save CSV Export',
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(csv)),
      );
      return savedPath; // null if the user cancelled the dialog
    }

    // Mobile: write to a temp file and hand off to the native share sheet.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csv);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'MonoBal export — ${monthKeyToLabel(monthKey)}',
    );
    return null;
  }
}