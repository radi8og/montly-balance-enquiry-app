import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/transaction.dart';

/// Central place for every piece of data the app persists locally via
/// SharedPreferences: the starting balance (and which month it applies to),
/// the transaction list, and the dark-mode preference.
///
/// Keeping all key names and read/write logic here means the rest of the
/// app never touches SharedPreferences directly.
class StorageService {
  static const _kStartingBalanceKey = 'starting_balance';
  static const _kBalanceMonthKey = 'balance_month';
  static const _kTransactionsKey = 'transactions';
  static const _kDarkModeKey = 'dark_mode';

  // ---- Starting balance ----

  Future<double?> getStartingBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kStartingBalanceKey);
  }

  Future<String?> getBalanceMonthKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBalanceMonthKey);
  }

  Future<void> saveStartingBalance(double balance, String monthKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kStartingBalanceKey, balance);
    await prefs.setString(_kBalanceMonthKey, monthKey);
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
}
