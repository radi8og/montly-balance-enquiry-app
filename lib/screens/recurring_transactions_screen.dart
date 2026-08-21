import 'package:flutter/material.dart';
import '../models/recurring_transaction.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../utils/category_utils.dart';
import '../utils/currency_utils.dart';

class RecurringTransactionsScreen extends StatefulWidget {
  final String currencySymbol;

  const RecurringTransactionsScreen({super.key, required this.currencySymbol});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
  final StorageService _storage = StorageService();
  bool _isLoading = true;
  List<RecurringTransaction> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _storage.getRecurringTransactions();
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _save() async {
    await _storage.saveRecurringTransactions(_items);
  }

  void _openEditor({RecurringTransaction? existing}) {
    final isExpense = existing != null ? existing.amount < 0 : true;
    bool localIsExpense = isExpense;
    final titleController = TextEditingController(text: existing?.title ?? '');
    final amountController = TextEditingController(
      text: existing != null ? existing.amount.abs().toStringAsFixed(2) : '',
    );
    String? errorText;
    String selectedCategory = existing != null &&
            categoriesFor(isExpense: isExpense).contains(existing.category)
        ? existing.category
        : categoriesFor(isExpense: isExpense).first;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null
              ? 'Add Recurring Item'
              : 'Edit Recurring Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Income')),
                  ButtonSegment(value: true, label: Text('Expense')),
                ],
                selected: {localIsExpense},
                onSelectionChanged: (selection) {
                  setDialogState(() {
                    localIsExpense = selection.first;
                    selectedCategory = categoriesFor(isExpense: localIsExpense).first;
                  });
                },
              ),
              const SizedBox(height: 12),
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
                  prefixText: '${widget.currencySymbol} ',
                  errorText: errorText,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categoriesFor(isExpense: localIsExpense)
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
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Automatically added on the 1st of every month.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
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
                  setDialogState(() => errorText = 'Enter a valid amount');
                  return;
                }
                if (title.isEmpty) {
                  setDialogState(() => errorText = null);
                  return;
                }

                final signedAmount = localIsExpense ? -amount : amount;

                setState(() {
                  if (existing == null) {
                    _items.add(RecurringTransaction(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      title: title,
                      amount: signedAmount,
                      category: selectedCategory,
                    ));
                  } else {
                    final index = _items.indexWhere((r) => r.id == existing.id);
                    if (index != -1) {
                      _items[index] = existing.copyWith(
                        title: title,
                        amount: signedAmount,
                        category: selectedCategory,
                      );
                    }
                  }
                });
                await _save();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(RecurringTransaction item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Item?'),
        content: Text(
          'Remove "${item.title}"? This won\'t affect transactions already '
          'added to past or current months — only future auto-generation stops.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              setState(() => _items.removeWhere((r) => r.id == item.id));
              await _save();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(RecurringTransaction item, bool value) async {
    setState(() {
      final index = _items.indexWhere((r) => r.id == item.id);
      if (index != -1) {
        _items[index] = item.copyWith(active: value);
      }
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Transactions'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No recurring items yet.\nAdd things like Rent, Salary, '
                      'or a subscription to have them added automatically '
                      'every month.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isExpense = item.amount < 0;
                    return ListTile(
                      onTap: () => _openEditor(existing: item),
                      leading: Icon(
                        categoryIcon(item.category),
                        color: isExpense ? AppColors.expense : AppColors.income,
                      ),
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.category} · Every 1st of the month',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${isExpense ? '-' : '+'}${formatMoney(widget.currencySymbol, item.amount.abs())}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isExpense ? AppColors.expense : AppColors.income,
                            ),
                          ),
                          Switch(
                            value: item.active,
                            onChanged: (value) => _toggleActive(item, value),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20),
                            color: Colors.grey,
                            onPressed: () => _confirmDelete(item),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Add Recurring Item',
        child: const Icon(Icons.add),
      ),
    );
  }
}