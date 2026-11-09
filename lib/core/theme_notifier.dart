import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static final ThemeNotifier instance = ThemeNotifier._internal();

  ThemeNotifier._internal() {
    _loadThemeMode();
  }

  factory ThemeNotifier() => instance;

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode newMode) async {
    if (newMode == _themeMode) return;
    _themeMode = newMode;
    notifyListeners();
    await _saveThemeMode(newMode);
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('themeMode');
      if (value == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (value == 'light') {
        _themeMode = ThemeMode.light;
      }
    } catch (_) {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }
}
