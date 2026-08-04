import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  static const _kDarkModeKey = 'dark_mode';

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_kDarkModeKey) ?? false;
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _toggleTheme() async {
    final newMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = newMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkModeKey, newMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonoBal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      themeMode: _themeMode,
      home: BalanceHomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class Transaction {
  final String id;
  final String title;
  final double amount; // positive = income, negative = expense
  final DateTime date;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'] as String? ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}

class BalanceHomePage extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const BalanceHomePage({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
  });

  @override
  State<BalanceHomePage> createState() => _BalanceHomePageState();
}

class _BalanceHomePageState extends State<BalanceHomePage> {
  double _startingBalance = 0.0;
  bool _startingBalanceSet = false;
  bool _isLoading = true;
  final List<Transaction> _transactions = [];

  final DateTime _currentMonth = DateTime.now();

  static const _kStartingBalanceKey = 'starting_balance';
  static const _kTransactionsKey = 'transactions';
  static const _kBalanceMonthKey = 'balance_month';

  String get _currentMonthKey =>
      '${_currentMonth.year}-${_currentMonth.month}';

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedBalance = prefs.getDouble(_kStartingBalanceKey);
    final savedMonthKey = prefs.getString(_kBalanceMonthKey);
    final savedTransactionsJson = prefs.getString(_kTransactionsKey);

    if (savedTransactionsJson != null) {
      final List decoded = jsonDecode(savedTransactionsJson) as List;
      _transactions.addAll(
        decoded.map((e) => Transaction.fromJson(e as Map<String, dynamic>)),
      );
    }

    // Only reuse the saved balance if it was set for THIS month.
    final validForThisMonth =
        savedBalance != null && savedMonthKey == _currentMonthKey;

    setState(() {
      _isLoading = false;
      if (validForThisMonth) {
        _startingBalance = savedBalance;
        _startingBalanceSet = true;
      } else {
        _startingBalanceSet = false;
      }
    });

    if (!_startingBalanceSet) {
      _promptStartingBalance();
    }
  }

  Future<void> _saveStartingBalance() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kStartingBalanceKey, _startingBalance);
    await prefs.setString(_kBalanceMonthKey, _currentMonthKey);
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_transactions.map((t) => t.toJson()).toList());
    await prefs.setString(_kTransactionsKey, encoded);
  }

  double get _monthTotal {
    double total = 0;
    for (var t in _transactions) {
      if (t.date.year == _currentMonth.year &&
          t.date.month == _currentMonth.month) {
        total += t.amount;
      }
    }
    return total;
  }

  double get _currentBalance => _startingBalance + _monthTotal;

  List<Transaction> get _monthTransactions {
    final list = _transactions
        .where((t) =>
            t.date.year == _currentMonth.year &&
            t.date.month == _currentMonth.month)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  String _monthLabel() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  void _promptStartingBalance() {
    final controller = TextEditingController(
      text: _startingBalanceSet ? _startingBalance.toStringAsFixed(2) : '',
    );
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(
          _startingBalanceSet ? 'Reset Starting Balance' : 'Set Starting Balance',
        ),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: 'Enter your current balance',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null) {
                setState(() {
                  _startingBalance = value;
                  _startingBalanceSet = true;
                });
                _saveStartingBalance();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmResetBalance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Starting Balance?'),
        content: const Text(
          'This lets you correct your starting balance for this month. '
          'Your existing transactions will stay untouched, and the balance '
          'will recalculate from the new starting value.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _promptStartingBalance();
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _addTransaction({required bool isExpense}) {
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isExpense ? 'Add Expense' : 'Add Income'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                autofocus: true,
              ),
              TextField(
                controller: amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '₹ ',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountController.text);
                final title = titleController.text.trim();

                if (!isExpense && _currentBalance == 0) {
                  setDialogState(() {
                    errorText = 'Please add sufficient balance amount.';
                  });
                  return;
                }
                if (amount == null || amount <= 0) {
                  setDialogState(() {
                    errorText = 'Enter a valid amount';
                  });
                  return;
                }
                if (title.isEmpty) {
                  setDialogState(() {
                    errorText = null;
                  });
                  return;
                }
                if (isExpense && amount > _currentBalance) {
                  setDialogState(() {
                    errorText =
                        'Insufficient balance (₹${_currentBalance.toStringAsFixed(2)} available)';
                  });
                  return;
                }

                setState(() {
                  _transactions.add(
                    Transaction(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      amount: isExpense ? -amount : amount,
                      date: DateTime.now(),
                    ),
                  );
                });
                _saveTransactions();
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteTransaction(Transaction t) {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == t.id);
    });
    _saveTransactions();
  }

  void _confirmDelete(Transaction t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Remove "${t.title}" (₹${t.amount.abs().toStringAsFixed(2)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _deleteTransaction(t);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/icon/icon.png'),
        ),
        title: Text(_monthLabel()),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Reset starting balance',
            onPressed: _confirmResetBalance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Column(
                    children: [
                      const Text(
                        'Current Balance',
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${_currentBalance.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This month: ${_monthTotal >= 0 ? '+' : ''}₹${_monthTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _monthTotal >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _monthTransactions.isEmpty
                      ? const Center(
                          child: Text(
                            'No transactions yet this month.\nAdd income or an expense below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _monthTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _monthTransactions[index];
                            final isExpense = t.amount < 0;
                            return Dismissible(
                              key: ValueKey(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                color: Colors.red,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                _confirmDelete(t);
                                return false; // dialog handles removal
                              },
                              child: ListTile(
                                leading: Icon(
                                  isExpense
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isExpense ? Colors.red : Colors.green,
                                ),
                                title: Text(t.title),
                                subtitle: Text(
                                  '${t.date.day}/${t.date.month}/${t.date.year}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isExpense ? '-' : '+'}₹${t.amount.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isExpense
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 20),
                                      color: Colors.grey,
                                      onPressed: () => _confirmDelete(t),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'income',
            onPressed: () => _addTransaction(isExpense: false),
            backgroundColor: Colors.green,
            tooltip: 'Add Income',
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'expense',
            onPressed: () => _addTransaction(isExpense: true),
            backgroundColor: Colors.red,
            tooltip: 'Add Expense',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
