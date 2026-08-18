/// Formats an amount with the given currency symbol.
/// Kept as a single top-level function so every screen/service formats
/// money identically, regardless of which currency the user has chosen.
String formatMoney(String currencySymbol, double amount) =>
    '$currencySymbol${amount.toStringAsFixed(2)}';

/// Converts a stored month key like "2026-7" into "July 2026".
String monthKeyToLabel(String monthKey) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  final parts = monthKey.split('-');
  final year = int.parse(parts[0]);
  final month = int.parse(parts[1]);
  return '${months[month - 1]} $year';
}

/// Builds the "YYYY-M" key used internally for grouping/storage.
String monthKeyFor(DateTime date) => '${date.year}-${date.month}';

/// Zero-padded "YYYY-MM" used for filenames only (e.g. MonoBal_2026-07.csv).
String paddedMonthKey(String monthKey) {
  final parts = monthKey.split('-');
  final year = parts[0];
  final month = parts[1].padLeft(2, '0');
  return '$year-$month';
}