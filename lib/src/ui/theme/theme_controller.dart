import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller that manages and persists the application's theme configuration.
///
/// Holds the theme mode (light, dark, system) and Material You dynamic color
/// settings, saving selections to local [SharedPreferences] key-value storage.
class ThemeController extends ChangeNotifier {
  ThemeController();

  static const _themeModeKey = 'theme_mode';
  static const _useDynamicColorKey = 'use_dynamic_color';

  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode for premium branding
  bool _useDynamicColor = true; // Default to true for Material You support

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  /// Loads persisted settings from local storage. Awaited in main before runApp.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeIndex = prefs.getInt(_themeModeKey);
      if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[modeIndex];
      }

      _useDynamicColor = prefs.getBool(_useDynamicColorKey) ?? true;
      notifyListeners();
    } catch (_) {
      // Gracefully fall back to defaults if SharedPreferences encounters an error
    }
  }

  /// Updates the theme mode and saves it to local storage.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, mode.index);
    } catch (_) {}
  }

  /// Updates the dynamic colors setting and saves it to local storage.
  Future<void> setUseDynamicColor(bool useDynamic) async {
    if (_useDynamicColor == useDynamic) return;
    _useDynamicColor = useDynamic;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_useDynamicColorKey, useDynamic);
    } catch (_) {}
  }
}
