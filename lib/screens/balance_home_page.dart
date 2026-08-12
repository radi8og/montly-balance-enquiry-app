import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

/// Which subset of this month's transactions to show.
enum TransactionFilter { all, income, expense }

/// Currency symbols the user can choose from in the App Bar.
const List<String> kCurrencyOptions = ['₹', '\$', '€', '£'];

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
  final StorageService _storage = StorageService();

  double _startingBalance = 0.0;
  bool _startingBalanceSet = false;
  bool _isLoading = true;
  final List<Transaction> _transactions = [];

  String _currencySymbol = '₹';

  String _searchQuery = '';
  TransactionFilter _filter = TransactionFilter.all;

  final DateTime _currentMonth = DateTime.now();

  String get _currentMonthKey =>
      '${_currentMonth.year}-${_currentMonth.month}';

  // ---------------------------------------------------------------------
  // Lifecycle / loading
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final savedBalance = await _storage.getStartingBalance();
    final savedMonthKey = await _storage.getBalanceMonthKey();
    final savedTransactions = await _storage.getTransactions();
    final savedCurrency = await _storage.getCurrencySymbol();

    _transactions.addAll(savedTransactions);

    // Only reuse the saved balance if it was set for THIS month.
    final validForThisMonth =
        savedBalance != null && savedMonthKey == _currentMonthKey;

    setState(() {
      _isLoading = false;
      _currencySymbol = savedCurrency;
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

  Future<void> _changeCurrency(String symbol) async {
    setState(() {
      _currencySymbol = symbol;
    });
    await _storage.setCurrencySymbol(symbol);
  }

  String _money(double amount) => '$_currencySymbol${amount.toStringAsFixed(2)}';

  // ---------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------

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

  /// Month transactions after applying the search query and filter chip.
  List<Transaction> get _visibleTransactions {
    return _monthTransactions.where((t) {
      final matchesQuery =
          _searchQuery.isEmpty ||
          t.title.toLowerCase().contains(_searchQuery.toLowerCase());

      final isExpense = t.amount < 0;
      final matchesFilter = switch (_filter) {
        TransactionFilter.all => true,
        TransactionFilter.income => !isExpense,
        TransactionFilter.expense => isExpense,
      };

      return matchesQuery && matchesFilter;
    }).toList();
  }

  String _monthLabel() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  // ---------------------------------------------------------------------
  // Starting balance dialog
  // ---------------------------------------------------------------------

  void _promptStartingBalance() {
    final controller = TextEditingController(
      text: _startingBalanceSet ? _startingBalance.toStringAsFixed(2) : '',
    );
    String? errorText;
    final isResetting = _startingBalanceSet;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            isResetting ? 'Reset Starting Balance' : 'Set Starting Balance',
          ),
          content: TextField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '$_currencySymbol ',
              hintText: 'Enter your current balance',
              errorText: errorText,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final value = double.tryParse(controller.text);
                if (value == null) {
                  setDialogState(() {
                    errorText = 'Enter a valid amount';
                  });
                  return;
                }
                if (value < 0) {
                  setDialogState(() {
                    errorText = 'Balance cannot be negative';
                  });
                  return;
                }
                setState(() {
                  if (isResetting) {
                    _transactions.removeWhere((t) =>
                        t.date.year == _currentMonth.year &&
                        t.date.month == _currentMonth.month);
                  }
                  _startingBalance = value;
                  _startingBalanceSet = true;
                });
                await _storage.saveStartingBalance(value, _currentMonthKey);
                await _storage.saveTransactions(_transactions);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmResetBalance() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Starting Balance?'),
        content: const Text(
          'This lets you set a new starting balance for this month. '
          'All transactions logged so far this month will be cleared, '
          'and the balance will start fresh from the new value.',
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

  // ---------------------------------------------------------------------
  // Add transaction
  // ---------------------------------------------------------------------

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
                  prefixText: '$_currencySymbol ',
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
              onPressed: () async {
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
                        'Insufficient balance (${_money(_currentBalance)} available)';
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
                await _storage.saveTransactions(_transactions);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Edit transaction  (v1.9)
  // ---------------------------------------------------------------------

  void _editTransaction(Transaction original) {
    final isExpense = original.amount < 0;
    final titleController = TextEditingController(text: original.title);
    final amountController = TextEditingController(
      text: original.amount.abs().toStringAsFixed(2),
    );
    String? errorText;

    // Balance as if this transaction didn't exist yet — lets the user
    // re-save the same or a smaller amount without being falsely blocked
    // by its own previous contribution to the balance.
    final balanceExcludingThis = _currentBalance - original.amount;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isExpense ? 'Edit Expense' : 'Edit Income'),
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
                  prefixText: '$_currencySymbol ',
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
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                final title = titleController.text.trim();

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
                if (isExpense && amount > balanceExcludingThis) {
                  setDialogState(() {
                    errorText =
                        'Insufficient balance (${_money(balanceExcludingThis)} available)';
                  });
                  return;
                }

                setState(() {
                  final index =
                      _transactions.indexWhere((tx) => tx.id == original.id);
                  if (index != -1) {
                    _transactions[index] = Transaction(
                      id: original.id,
                      title: title,
                      amount: isExpense ? -amount : amount,
                      date: original.date, // keep the original entry date
                    );
                  }
                });
                await _storage.saveTransactions(_transactions);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Delete transaction
  // ---------------------------------------------------------------------

  void _deleteTransaction(Transaction t) async {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == t.id);
    });
    await _storage.saveTransactions(_transactions);
  }

  void _confirmDelete(Transaction t) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text('Remove "${t.title}" (${_money(t.amount.abs())})?'),
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

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/icon/icon.png'),
        ),
        title: Text(_monthLabel()),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Change currency',
            initialValue: _currencySymbol,
            onSelected: _changeCurrency,
            itemBuilder: (context) => kCurrencyOptions
                .map((symbol) => PopupMenuItem<String>(
                      value: symbol,
                      child: Text(symbol),
                    ))
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                widthFactor: 1,
                child: Text(
                  _currencySymbol,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
            ),
            tooltip: widget.isDarkMode
                ? 'Switch to light mode'
                : 'Switch to dark mode',
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
                        _money(_currentBalance),
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This month: ${_monthTotal >= 0 ? '+' : ''}${_money(_monthTotal)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: _monthTotal >= 0
                              ? AppColors.incomeText(context)
                              : AppColors.expenseText(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---- Search + filter bar (v1.9) ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search transactions',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('All'),
                          selected: _filter == TransactionFilter.all,
                          onSelected: (_) =>
                              setState(() => _filter = TransactionFilter.all),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Income'),
                          selected: _filter == TransactionFilter.income,
                          onSelected: (_) => setState(
                              () => _filter = TransactionFilter.income),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Expenses'),
                          selected: _filter == TransactionFilter.expense,
                          onSelected: (_) => setState(
                              () => _filter = TransactionFilter.expense),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: _visibleTransactions.isEmpty
                      ? Center(
                          child: Text(
                            _monthTransactions.isEmpty
                                ? 'No transactions yet this month.\nAdd income or an expense below.'
                                : 'No transactions match your search.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _visibleTransactions.length,
                          itemBuilder: (context, index) {
                            final t = _visibleTransactions[index];
                            final isExpense = t.amount < 0;
                            return Dismissible(
                              key: ValueKey(t.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20),
                                color: AppColors.expense,
                                child: const Icon(Icons.delete,
                                    color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                _confirmDelete(t);
                                return false; // dialog handles removal
                              },
                              child: ListTile(
                                onTap: () => _editTransaction(t),
                                leading: Icon(
                                  isExpense
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isExpense
                                      ? AppColors.expense
                                      : AppColors.income,
                                ),
                                title: Text(t.title),
                                subtitle: Text(
                                  '${t.date.day}/${t.date.month}/${t.date.year}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${isExpense ? '-' : '+'}${_money(t.amount.abs())}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isExpense
                                            ? AppColors.expense
                                            : AppColors.income,
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
            backgroundColor: AppColors.income,
            tooltip: 'Add Income',
            child: const Icon(Icons.add),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'expense',
            onPressed: () => _addTransaction(isExpense: true),
            backgroundColor: AppColors.expense,
            tooltip: 'Add Expense',
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
