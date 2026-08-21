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

/// A distinct color per category, used for the breakdown chart's pie
/// slices and matching legend swatches. Kept separate from AppColors'
/// income/expense red-green, since a chart needs one color per *category*
/// rather than per transaction type.
Color categoryColor(String category) {
  switch (category) {
    case 'Food':
      return const Color(0xFFFF7043); // deep orange
    case 'Rent':
      return const Color(0xFF5C6BC0); // indigo
    case 'Transport':
      return const Color(0xFF26A69A); // teal
    case 'Entertainment':
      return const Color(0xFFAB47BC); // purple
    case 'Utilities':
      return const Color(0xFFFFCA28); // amber
    case 'Shopping':
      return const Color(0xFFEC407A); // pink
    case 'Health':
      return const Color(0xFF66BB6A); // green
    case 'Salary':
      return const Color(0xFF42A5F5); // blue
    case 'Freelance':
      return const Color(0xFF8D6E63); // brown
    case 'Gift':
      return const Color(0xFFEF5350); // red
    case 'Investment':
      return const Color(0xFF29B6F6); // light blue
    default:
      return const Color(0xFF9E9E9E); // grey — Other
  }
}