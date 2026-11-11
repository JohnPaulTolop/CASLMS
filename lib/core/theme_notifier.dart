import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier instance = ThemeNotifier._internal();

  ThemeNotifier._internal() {
    _loadThemeMode();
  }

  factory ThemeNotifier() => instance;

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode newMode) async {
    if (newMode == _themeMode) return;
    _themeMode = newMode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', newMode.name);
    } catch (_) {}
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('themeMode');
      if (value == 'dark') {
        _themeMode = ThemeMode.dark;
        notifyListeners();
      } else if (value == 'light') {
        _themeMode = ThemeMode.light;
        notifyListeners();
      }
    } catch (_) {}
  }
}
