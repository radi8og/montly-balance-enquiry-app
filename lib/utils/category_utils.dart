import 'package:flutter/material.dart';

/// Categories offered when adding/editing an Expense.
const List<String> kExpenseCategories = [
  'Food',
  'Rent',
  'Transport',
  'Entertainment',
  'Utilities',
  'Shopping',
  'Health',
  'Other',
];

/// Categories offered when adding/editing Income.
const List<String> kIncomeCategories = [
  'Salary',
  'Freelance',
  'Gift',
  'Investment',
  'Other',
];

/// Returns the right category list for the transaction type being entered.
List<String> categoriesFor({required bool isExpense}) =>
    isExpense ? kExpenseCategories : kIncomeCategories;

/// A small icon per category, used in the transaction list and dialogs.
IconData categoryIcon(String category) {
  switch (category) {
    case 'Food':
      return Icons.restaurant;
    case 'Rent':
      return Icons.home;
    case 'Transport':
      return Icons.directions_car;
    case 'Entertainment':
      return Icons.movie;
    case 'Utilities':
      return Icons.bolt;
    case 'Shopping':
      return Icons.shopping_bag;
    case 'Health':
      return Icons.health_and_safety;
    case 'Salary':
      return Icons.payments;
    case 'Freelance':
      return Icons.work;
    case 'Gift':
      return Icons.card_giftcard;
    case 'Investment':
      return Icons.trending_up;
    default:
      return Icons.category;
  }
}