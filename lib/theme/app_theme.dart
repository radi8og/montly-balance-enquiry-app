import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Light and dark ThemeData for the app, built from AppColors so the
/// palette only needs to be defined in one place.
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        primarySwatch: AppColors.primarySwatch,
        brightness: Brightness.light,
        useMaterial3: true,
      );

  static ThemeData get dark => ThemeData(
        primarySwatch: AppColors.primarySwatch,
        brightness: Brightness.dark,
        useMaterial3: true,
      );
}
