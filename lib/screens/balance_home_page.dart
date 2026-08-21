import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../services/backup_service.dart';
import '../services/csv_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/category_utils.dart';
import '../utils/currency_utils.dart';
import '../widgets/month_summary_card.dart';
import '../widgets/transaction_tile.dart';
import 'archive_screen.dart';

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final StorageService _storage = StorageService();
  late final BackupService _backup = BackupService(_storage);

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  double _startingBalance = 0.0;
  bool _startingBalanceSet = false;
  bool _isLoading = true;
  final List<Transaction> _transactions = [];

  String _currencySymbol = '₹';

  String _searchQuery = '';
  TransactionFilter _filter = TransactionFilter.all;

  final DateTime _currentMonth = DateTime.now();

  String get _currentMonthKey => monthKeyFor(_currentMonth);

  // ---------------------------------------------------------------------
  // Lifecycle / loading
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _storage.migrateLegacyBalanceIfNeeded();

    final savedBalance = await _storage.getStartingBalanceForMonth(_currentMonthKey);
    final allTransactions = await _storage.getTransactions();
    final savedCurrency = await _storage.getCurrencySymbol();

    _transactions
      ..clear()
      ..addAll(allTransactions);

    setState(() {
      _isLoading = false;
      _currencySymbol = savedCurrency;
      if (savedBalance != null) {
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

  String _money(double amount) => formatMoney(_currencySymbol, amount);

  // ---------------------------------------------------------------------
  // Derived data
  // ---------------------------------------------------------------------

  double get _monthTotal {
    double total = 0;
    for (var t in _transactions) {
      if (monthKeyFor(t.date) == _currentMonthKey) {
        total += t.amount;
      }
    }
    return total;
  }

  double get _currentBalance => _startingBalance + _monthTotal;

  List<Transaction> get _monthTransactions {
    final list = _transactions
        .where((t) => monthKeyFor(t.date) == _currentMonthKey)
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  /// Month transactions after applying the search query and filter chip.
  List<Transaction> get _visibleTransactions {
    return _monthTransactions.where((t) {
      final matchesQuery = _searchQuery.isEmpty ||
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

  String _monthLabel() => monthKeyToLabel(_currentMonthKey);

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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  setDialogState(() => errorText = 'Enter a valid amount');
                  return;
                }
                if (value < 0) {
                  setDialogState(() => errorText = 'Balance cannot be negative');
                  return;
                }
                setState(() {
                  if (isResetting) {
                    _transactions.removeWhere(
                        (t) => monthKeyFor(t.date) == _currentMonthKey);
                  }
                  _startingBalance = value;
                  _startingBalanceSet = true;
                });
                await _storage.setStartingBalanceForMonth(_currentMonthKey, value);
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
  // Currency
  // ---------------------------------------------------------------------

  Future<void> _applyCurrencyChange(String symbol) async {
    setState(() {
      _currencySymbol = symbol;
      _transactions.removeWhere((t) => monthKeyFor(t.date) == _currentMonthKey);
      _startingBalanceSet = false;
      _startingBalance = 0.0;
    });
    await _storage.setCurrencySymbol(symbol);
    await _storage.saveTransactions(_transactions);
    await _storage.clearStartingBalanceForMonth(_currentMonthKey);
    _promptStartingBalance();
  }

  void _confirmCurrencyChange(String symbol) {
    if (symbol == _currencySymbol) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Currency?'),
        content: Text(
          'Switching to $symbol will clear this month\'s starting balance '
          'and all logged transactions, since amounts recorded in the old '
          'currency can\'t be converted automatically. You\'ll be asked to '
          'set a new starting balance in $symbol.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _applyCurrencyChange(symbol);
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
    String selectedCategory = categoriesFor(isExpense: isExpense).first;

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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$_currencySymbol ',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categoriesFor(isExpense: isExpense)
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon(c), size: 18),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCategory = value);
                  }
                },
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
                  setDialogState(
                      () => errorText = 'Please add sufficient balance amount.');
                  return;
                }
                if (amount == null || amount <= 0) {
                  setDialogState(() => errorText = 'Enter a valid amount');
                  return;
                }
                if (title.isEmpty) {
                  setDialogState(() => errorText = null);
                  return;
                }
                if (isExpense && amount > _currentBalance) {
                  setDialogState(() => errorText =
                      'Insufficient balance (${_money(_currentBalance)} available)');
                  return;
                }

                setState(() {
                  _transactions.add(
                    Transaction(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      amount: isExpense ? -amount : amount,
                      date: DateTime.now(),
                      category: selectedCategory,
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
  // Edit transaction
  // ---------------------------------------------------------------------

  void _editTransaction(Transaction original) {
    final isExpense = original.amount < 0;
    final titleController = TextEditingController(text: original.title);
    final amountController =
        TextEditingController(text: original.amount.abs().toStringAsFixed(2));
    String? errorText;

    final categoryOptions = categoriesFor(isExpense: isExpense);
    String selectedCategory =
        categoryOptions.contains(original.category) ? original.category : categoryOptions.first;

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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '$_currencySymbol ',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categoryOptions
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(categoryIcon(c), size: 18),
                              const SizedBox(width: 8),
                              Text(c),
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedCategory = value);
                  }
                },
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
                  setDialogState(() => errorText = 'Enter a valid amount');
                  return;
                }
                if (title.isEmpty) {
                  setDialogState(() => errorText = null);
                  return;
                }
                if (isExpense && amount > balanceExcludingThis) {
                  setDialogState(() => errorText =
                      'Insufficient balance (${_money(balanceExcludingThis)} available)');
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
                      date: original.date,
                      category: selectedCategory,
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
  // CSV export (current month)
  // ---------------------------------------------------------------------

  Future<void> _exportCurrentMonthCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await CsvService.exportAndShare(
        monthKey: _currentMonthKey,
        transactions: _monthTransactions,
        startingBalance: _startingBalance,
      );
      if (savedPath != null) {
        messenger.showSnackBar(SnackBar(content: Text('CSV saved to $savedPath')));
      } else if (_isDesktop) {
        // Desktop + null means the user cancelled the Save As dialog.
        messenger.showSnackBar(const SnackBar(content: Text('Export cancelled.')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('CSV exported.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // Backup / Restore
  // ---------------------------------------------------------------------

  Future<void> _exportBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final savedPath = await _backup.exportAndShare();
      if (savedPath != null) {
        messenger.showSnackBar(SnackBar(content: Text('Backup saved to $savedPath')));
      } else if (_isDesktop) {
        messenger.showSnackBar(const SnackBar(content: Text('Backup export cancelled.')));
      } else {
        messenger.showSnackBar(const SnackBar(content: Text('Backup exported.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Backup failed: $e')));
    }
  }

  Future<void> _importBackup() async {
    final messenger = ScaffoldMessenger.of(context);
    Map<String, dynamic>? data;

    try {
      data = await _backup.pickAndValidateBackup();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      return;
    }

    if (data == null) return; // user cancelled the file picker
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: const Text(
          'Restoring will overwrite current local app data. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _backup.applyRestore(data);
      setState(() {
        _isLoading = true;
        _transactions.clear();
      });
      await _loadData();
      if (mounted) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Backup restored successfully.')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------

  void _openArchive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArchiveScreen(
          currencySymbol: _currencySymbol,
          currentMonthKey: _currentMonthKey,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/icon/icon.png'),
        ),
        title: Text(_monthLabel()),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          PopupMenuButton<String>(
            tooltip: 'Change currency',
            initialValue: _currencySymbol,
            onSelected: _confirmCurrencyChange,
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
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                ),
                child: Row(
                  children: [
                    Image.asset('assets/icon/icon.png', width: 48, height: 48),
                    const SizedBox(width: 12),
                    const Text('MonoBal', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Monthly History'),
                onTap: () {
                  Navigator.pop(context);
                  _openArchive();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset Starting Balance'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmResetBalance();
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Data & Backups',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('Export Month to CSV'),
                onTap: () {
                  Navigator.pop(context);
                  _exportCurrentMonthCsv();
                },
              ),
              ListTile(
                leading: const Icon(Icons.backup),
                title: const Text('Export Backup (JSON)'),
                onTap: () {
                  Navigator.pop(context);
                  _exportBackup();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Import / Restore Backup'),
                onTap: () {
                  Navigator.pop(context);
                  _importBackup();
                },
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                MonthSummaryCard(
                  balance: _currentBalance,
                  netForMonth: _monthTotal,
                  currencySymbol: _currencySymbol,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search transactions',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          onSelected: (_) => setState(() => _filter = TransactionFilter.all),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Income'),
                          selected: _filter == TransactionFilter.income,
                          onSelected: (_) => setState(() => _filter = TransactionFilter.income),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Expenses'),
                          selected: _filter == TransactionFilter.expense,
                          onSelected: (_) => setState(() => _filter = TransactionFilter.expense),
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
                            return TransactionTile(
                              transaction: t,
                              currencySymbol: _currencySymbol,
                              onTap: () => _editTransaction(t),
                              onDelete: () => _confirmDelete(t),
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