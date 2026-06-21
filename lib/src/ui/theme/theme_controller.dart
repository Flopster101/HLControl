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
  static const _isDeveloperModeKey = 'is_developer_mode';
  static const _isMockConnectedKey = 'is_mock_connected';
  static const _mockBatteryPercentKey = 'mock_battery_percent';

  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode for premium branding
  bool _useDynamicColor = true; // Default to true for Material You support
  bool _isDeveloperMode = false; // Hidden developer mode
  bool _isMockConnected = false; // Default to false (simulation mode disabled by default)
  int _mockBatteryPercent = 85;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  bool get isDeveloperMode => _isDeveloperMode;
  bool get isMockConnected => _isMockConnected;
  int get mockBatteryPercent => _mockBatteryPercent;

  /// Loads persisted settings from local storage. Awaited in main before runApp.
  Future<void> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final modeIndex = prefs.getInt(_themeModeKey);
      if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
        _themeMode = ThemeMode.values[modeIndex];
      }

      _useDynamicColor = prefs.getBool(_useDynamicColorKey) ?? true;
      _isDeveloperMode = prefs.getBool(_isDeveloperModeKey) ?? false;
      _isMockConnected = prefs.getBool(_isMockConnectedKey) ?? false;
      _mockBatteryPercent = prefs.getInt(_mockBatteryPercentKey) ?? 85;
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

  /// Updates the developer mode setting and saves it to local storage.
  Future<void> setDeveloperMode(bool value) async {
    if (_isDeveloperMode == value) return;
    _isDeveloperMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isDeveloperModeKey, value);
    } catch (_) {}
  }

  /// Updates the mock connection setting and saves it to local storage.
  Future<void> setMockConnected(bool value) async {
    if (_isMockConnected == value) return;
    _isMockConnected = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isMockConnectedKey, value);
    } catch (_) {}
  }

  /// Updates the mock battery percentage and saves it to local storage.
  Future<void> setMockBatteryPercent(int value) async {
    if (_mockBatteryPercent == value) return;
    _mockBatteryPercent = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_mockBatteryPercentKey, value);
    } catch (_) {}
  }
}
