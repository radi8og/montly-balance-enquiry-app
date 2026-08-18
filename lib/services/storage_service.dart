import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';

/// Central place for every piece of data the app persists locally via
/// SharedPreferences: starting balances (per month), the full transaction
/// history, the dark-mode preference, and the currency symbol.
///
/// Keeping all key names and read/write logic here means the rest of the
/// app never touches SharedPreferences directly. This also makes backup /
/// restore straightforward, since export/import just serialize and
/// deserialize the same keys this class already owns.
class StorageService {
  static const _kStartingBalancesKey = 'starting_balances'; // Map<monthKey, double>
  static const _kTransactionsKey = 'transactions';
  static const _kDarkModeKey = 'dark_mode';
  static const _kCurrencySymbolKey = 'currency_symbol';

  // Legacy v1.x keys — only read once, for migration.
  static const _kLegacyStartingBalanceKey = 'starting_balance';
  static const _kLegacyBalanceMonthKey = 'balance_month';

  /// Migrates a pre-v2.0 single starting balance (one value + one month key)
  /// into the new per-month map format. Safe to call every launch — it's a
  /// no-op once migration has happened, since the legacy keys are removed
  /// after migrating.
  Future<void> migrateLegacyBalanceIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyBalance = prefs.getDouble(_kLegacyStartingBalanceKey);
    final legacyMonthKey = prefs.getString(_kLegacyBalanceMonthKey);

    if (legacyBalance != null && legacyMonthKey != null) {
      final balances = await getStartingBalances();
      balances.putIfAbsent(legacyMonthKey, () => legacyBalance);
      await saveStartingBalances(balances);
      await prefs.remove(_kLegacyStartingBalanceKey);
      await prefs.remove(_kLegacyBalanceMonthKey);
    }
  }

  // ---- Starting balances (per month) ----

  Future<Map<String, double>> getStartingBalances() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kStartingBalancesKey);
    if (json == null) return {};
    final Map<String, dynamic> decoded = jsonDecode(json);
    return decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
  }

  Future<void> saveStartingBalances(Map<String, double> balances) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStartingBalancesKey, jsonEncode(balances));
  }

  Future<double?> getStartingBalanceForMonth(String monthKey) async {
    final balances = await getStartingBalances();
    return balances[monthKey];
  }

  Future<void> setStartingBalanceForMonth(String monthKey, double balance) async {
    final balances = await getStartingBalances();
    balances[monthKey] = balance;
    await saveStartingBalances(balances);
  }

  Future<void> clearStartingBalanceForMonth(String monthKey) async {
    final balances = await getStartingBalances();
    balances.remove(monthKey);
    await saveStartingBalances(balances);
  }

  // ---- Transactions ----

  Future<List<Transaction>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTransactionsKey);
    if (json == null) return [];
    final List decoded = jsonDecode(json) as List;
    return decoded
        .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveTransactions(List<Transaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(transactions.map((t) => t.toJson()).toList());
    await prefs.setString(_kTransactionsKey, encoded);
  }

  // ---- Theme preference ----

  Future<bool> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDarkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, isDark);
  }

  // ---- Currency preference ----

  Future<String> getCurrencySymbol() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrencySymbolKey) ?? '₹';
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencySymbolKey, symbol);
  }

  // ---- Backup / Restore ----

  /// Bundles every piece of app data into one JSON-serializable map.
  Future<Map<String, dynamic>> exportAllData() async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getString(_kTransactionsKey);
    final balancesJson = prefs.getString(_kStartingBalancesKey);

    return {
      'backup_version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'transactions':
          transactionsJson != null ? jsonDecode(transactionsJson) : [],
      'starting_balances':
          balancesJson != null ? jsonDecode(balancesJson) : {},
      'dark_mode': prefs.getBool(_kDarkModeKey) ?? false,
      'currency_symbol': prefs.getString(_kCurrencySymbolKey) ?? '₹',
    };
  }

  /// Validates that a decoded JSON map has the shape a MonoBal backup
  /// should have, without trusting its contents blindly.
  bool isValidBackup(Map<String, dynamic> data) {
    return data['transactions'] is List &&
        data['starting_balances'] is Map &&
        data['currency_symbol'] is String;
  }

  /// Overwrites all local data with the contents of a validated backup map.
  Future<void> importAllData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTransactionsKey, jsonEncode(data['transactions']));
    await prefs.setString(
        _kStartingBalancesKey, jsonEncode(data['starting_balances']));
    await prefs.setBool(_kDarkModeKey, data['dark_mode'] as bool? ?? false);
    await prefs.setString(
        _kCurrencySymbolKey, data['currency_symbol'] as String? ?? '₹');
  }
}