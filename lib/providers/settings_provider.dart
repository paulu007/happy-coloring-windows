import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static const String _soundKey = 'sound_enabled';
  static const String _vibrationKey = 'vibration_enabled';
  static const String _autoSaveKey = 'auto_save';
  static const String _showNumbersKey = 'show_numbers';
  static const String _highlightKey = 'highlight_regions';

  late SharedPreferences _prefs;

  // Settings
  ThemeMode _themeMode = ThemeMode.system;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _autoSave = true;
  bool _showNumbers = true;
  bool _highlightRegions = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get autoSave => _autoSave;
  bool get showNumbers => _showNumbers;
  bool get highlightRegions => _highlightRegions;

  /// Initialize settings from storage
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    
    _themeMode = ThemeMode.values[_prefs.getInt(_themeKey) ?? 0];
    _soundEnabled = _prefs.getBool(_soundKey) ?? true;
    _vibrationEnabled = _prefs.getBool(_vibrationKey) ?? true;
    _autoSave = _prefs.getBool(_autoSaveKey) ?? true;
    _showNumbers = _prefs.getBool(_showNumbersKey) ?? true;
    _highlightRegions = _prefs.getBool(_highlightKey) ?? true;
    
    notifyListeners();
  }

  /// Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  /// Toggle sound
  Future<void> toggleSound() async {
    _soundEnabled = !_soundEnabled;
    await _prefs.setBool(_soundKey, _soundEnabled);
    notifyListeners();
  }

  /// Toggle vibration
  Future<void> toggleVibration() async {
    _vibrationEnabled = !_vibrationEnabled;
    await _prefs.setBool(_vibrationKey, _vibrationEnabled);
    notifyListeners();
  }

  /// Toggle auto-save
  Future<void> toggleAutoSave() async {
    _autoSave = !_autoSave;
    await _prefs.setBool(_autoSaveKey, _autoSave);
    notifyListeners();
  }

  /// Toggle show numbers
  Future<void> toggleShowNumbers() async {
    _showNumbers = !_showNumbers;
    await _prefs.setBool(_showNumbersKey, _showNumbers);
    notifyListeners();
  }

  /// Toggle highlight regions
  Future<void> toggleHighlightRegions() async {
    _highlightRegions = !_highlightRegions;
    await _prefs.setBool(_highlightKey, _highlightRegions);
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _soundEnabled = true;
    _vibrationEnabled = true;
    _autoSave = true;
    _showNumbers = true;
    _highlightRegions = true;

    await _prefs.clear();
    notifyListeners();
  }
}