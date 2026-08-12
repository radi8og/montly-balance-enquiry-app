import 'package:flutter/material.dart';
import 'screens/balance_home_page.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final StorageService _storage = StorageService();
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final isDark = await _storage.getDarkMode();
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
    await _storage.setDarkMode(newMode == ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MonoBal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: BalanceHomePage(
        isDarkMode: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
