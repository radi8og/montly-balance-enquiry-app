import 'package:flutter/material.dart';

/// Every color used across the app lives here, so changing the app's
/// palette never requires touching screen or widget code.
class AppColors {
  AppColors._();

  static const MaterialColor primarySwatch = Colors.teal;

  static const Color income = Colors.green;
  static const Color expense = Colors.red;

  static Color incomeText(BuildContext context) => Colors.green[700]!;
  static Color expenseText(BuildContext context) => Colors.red[700]!;
}
