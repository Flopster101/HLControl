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
  static const _autoConnectLastHeadphonesKey = 'auto_connect_last_headphones';
  static const _minimizeToTrayKey = 'minimize_to_tray';
  static const _lastConnectedMacKey = 'last_connected_mac';
  static const _lastConnectedNameKey = 'last_connected_name';

  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode for premium branding
  bool _useDynamicColor = true; // Default to true for Material You support
  bool _isDeveloperMode = false; // Hidden developer mode
  bool _isMockConnected = false; // Default to false (simulation mode disabled by default)
  int _mockBatteryPercent = 85;
  bool _autoConnectLastHeadphones = true; // Auto connect to last headphones (enabled by default)
  bool _minimizeToTray = true; // Minimize to tray on close/minimize (enabled by default)
  String _lastConnectedMac = '';
  String _lastConnectedName = '';
  final Map<String, String> _deviceNames = {};

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  bool get isDeveloperMode => _isDeveloperMode;
  bool get isMockConnected => _isMockConnected;
  int get mockBatteryPercent => _mockBatteryPercent;
  bool get autoConnectLastHeadphones => _autoConnectLastHeadphones;
  bool get minimizeToTray => _minimizeToTray;
  String get lastConnectedMac => _lastConnectedMac;
  String get lastConnectedName {
    if (_lastConnectedMac.isEmpty) return '';
    final name = _deviceNames[_lastConnectedMac];
    if (name != null && name.isNotEmpty && name.toLowerCase() != 'disconnected') {
      return name;
    }
    if (_lastConnectedName.isNotEmpty && _lastConnectedName.toLowerCase() != 'disconnected') {
      return _lastConnectedName;
    }
    return '';
  }

  Map<String, String> get deviceNames => _deviceNames;

  String getDeviceName(String mac, String fallback) {
    if (mac.isEmpty) return fallback;
    final savedName = _deviceNames[mac];
    if (savedName != null && savedName.isNotEmpty && savedName.toLowerCase() != 'disconnected') {
      return savedName;
    }
    if (fallback.isNotEmpty && fallback.toLowerCase() != 'disconnected') {
      return fallback;
    }
    return mac;
  }

  Future<void> saveDeviceName(String mac, String name) async {
    if (mac.isEmpty || name.isEmpty || name.toLowerCase() == 'disconnected') return;
    if (_deviceNames[mac] == name) return;
    _deviceNames[mac] = name;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name_$mac', name);
    } catch (_) {}
  }

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
      _autoConnectLastHeadphones = prefs.getBool(_autoConnectLastHeadphonesKey) ?? true;
      _minimizeToTray = prefs.getBool(_minimizeToTrayKey) ?? true;
      _lastConnectedMac = prefs.getString(_lastConnectedMacKey) ?? '';
      _lastConnectedName = prefs.getString(_lastConnectedNameKey) ?? '';
      if (_lastConnectedName.toLowerCase() == 'disconnected') {
        _lastConnectedName = '';
        prefs.remove(_lastConnectedNameKey);
      }

      // Load all keys that start with 'device_name_'
      for (var key in prefs.getKeys()) {
        if (key.startsWith('device_name_')) {
          final mac = key.substring('device_name_'.length);
          final val = prefs.getString(key);
          if (val != null) {
            if (val.toLowerCase() == 'disconnected') {
              prefs.remove(key);
            } else {
              _deviceNames[mac] = val;
            }
          }
        }
      }

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

  /// Updates the auto connect last headphones setting and saves it to local storage.
  Future<void> setAutoConnectLastHeadphones(bool value) async {
    if (_autoConnectLastHeadphones == value) return;
    _autoConnectLastHeadphones = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoConnectLastHeadphonesKey, value);
    } catch (_) {}
  }

  /// Updates the minimize to tray setting and saves it to local storage.
  Future<void> setMinimizeToTray(bool value) async {
    if (_minimizeToTray == value) return;
    _minimizeToTray = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_minimizeToTrayKey, value);
    } catch (_) {}
  }

  /// Updates the last connected MAC and saves it to local storage.
  Future<void> setLastConnectedMac(String mac) async {
    if (_lastConnectedMac == mac) return;
    _lastConnectedMac = mac;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastConnectedMacKey, mac);
    } catch (_) {}
  }

  /// Updates the last connected friendly name and saves it to local storage.
  Future<void> setLastConnectedName(String name) async {
    if (name.isEmpty || name.toLowerCase() == 'disconnected') return;
    if (_lastConnectedName == name) return;
    _lastConnectedName = name;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastConnectedNameKey, name);
    } catch (_) {}
  }
}
