import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  static const _prefKey = 'app_theme_mode';

  ThemeMode get themeMode => _themeMode;

  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeStr = prefs.getString(_prefKey);
    _themeMode = _fromString(modeStr) ?? ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _toString(mode));
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return 'light';
      case ThemeMode.dark:  return 'dark';
      case ThemeMode.system:
      default: return 'system';
    }
  }

  static ThemeMode? _fromString(String? value) {
    switch (value) {
      case 'light': return ThemeMode.light;
      case 'dark':  return ThemeMode.dark;
      case 'system': return ThemeMode.system;
      default: return null;
    }
  }
}
