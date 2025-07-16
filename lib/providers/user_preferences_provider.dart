import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPreferencesProvider extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode';
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _medicationRemindersKey = 'medication_reminders';
  static const String _appointmentRemindersKey = 'appointment_reminders';
  static const String _primaryColorKey = 'primary_color';
  static const String _accentColorKey = 'accent_color';
  static const String _fontSizeKey = 'font_size';
  
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  Color _primaryColor = Colors.blue;
  Color _accentColor = Colors.blueAccent;
  double _fontSize = 1.0; // Scale factor
  
  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get medicationReminders => _medicationReminders;
  bool get appointmentReminders => _appointmentReminders;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  double get fontSize => _fontSize;
  
  // Available theme colors
  static const List<Color> availableColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.teal,
    Colors.indigo,
    Colors.pink,
  ];
  
  // Font size options
  static const List<double> fontSizeOptions = [0.8, 0.9, 1.0, 1.1, 1.2, 1.3];
  
  UserPreferencesProvider() {
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      _isDarkMode = prefs.getBool(_darkModeKey) ?? false;
      _notificationsEnabled = prefs.getBool(_notificationsEnabledKey) ?? true;
      _medicationReminders = prefs.getBool(_medicationRemindersKey) ?? true;
      _appointmentReminders = prefs.getBool(_appointmentRemindersKey) ?? true;
      _fontSize = prefs.getDouble(_fontSizeKey) ?? 1.0;
      
      // Load colors
      final primaryColorValue = prefs.getInt(_primaryColorKey);
      if (primaryColorValue != null) {
        _primaryColor = Color(primaryColorValue);
      }
      
      final accentColorValue = prefs.getInt(_accentColorKey);
      if (accentColorValue != null) {
        _accentColor = Color(accentColorValue);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    }
  }
  
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setBool(_darkModeKey, _isDarkMode);
      await prefs.setBool(_notificationsEnabledKey, _notificationsEnabled);
      await prefs.setBool(_medicationRemindersKey, _medicationReminders);
      await prefs.setBool(_appointmentRemindersKey, _appointmentReminders);
      await prefs.setDouble(_fontSizeKey, _fontSize);
      await prefs.setInt(_primaryColorKey, _primaryColor.value);
      await prefs.setInt(_accentColorKey, _accentColor.value);
    } catch (e) {
      debugPrint('Error saving preferences: $e');
    }
  }
  
  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> toggleMedicationReminders() async {
    _medicationReminders = !_medicationReminders;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setMedicationReminders(bool value) async {
    _medicationReminders = value;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> toggleAppointmentReminders() async {
    _appointmentReminders = !_appointmentReminders;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setAppointmentReminders(bool value) async {
    _appointmentReminders = value;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setPrimaryColor(Color color) async {
    _primaryColor = color;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    await _savePreferences();
    notifyListeners();
  }
  
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    await _savePreferences();
    notifyListeners();
  }
  
  // Method to clear all preferences
  Future<void> clearAllPreferences() async {
    _isDarkMode = false;
    _notificationsEnabled = true;
    _medicationReminders = true;
    _appointmentReminders = true;
    _primaryColor = Colors.blue;
    _accentColor = Colors.blueAccent;
    _fontSize = 1.0;
    await _savePreferences();
    notifyListeners();
  }
  
  // Get theme data based on current preferences
  ThemeData getThemeData() {
    final baseTheme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    
    return baseTheme.copyWith(
      primaryColor: _primaryColor,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: _primaryColor,
        secondary: _accentColor,
      ),
      textTheme: baseTheme.textTheme.apply(
        fontSizeFactor: _fontSize,
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
      ),
    );
  }
} 