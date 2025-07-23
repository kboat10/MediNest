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
  static const String _healthConditionKey = 'health_condition';
  
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;
  bool _medicationReminders = true;
  bool _appointmentReminders = true;
  Color _primaryColor = Color(0xFF3F51B5); // Indigo
  Color _accentColor = Color(0xFF009688); // Teal
  double _fontSize = 1.0; // Scale factor
  String _healthCondition = '';

  // Supported health conditions
  static const List<String> supportedConditions = [
    'Sickle Cell Disease',
    'Hypertension',
    'Diabetes',
    'Asthma',
    'Heart Disease',
    'Chronic Kidney Disease',
    'COPD',
    'Pregnancy',
    'Other',
    'None',
  ];
  
  // Getters
  bool get isDarkMode => _isDarkMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get medicationReminders => _medicationReminders;
  bool get appointmentReminders => _appointmentReminders;
  Color get primaryColor => _primaryColor;
  Color get accentColor => _accentColor;
  double get fontSize => _fontSize;
  String get healthCondition => _healthCondition;
  
  // Available theme colors
  static const List<Color> availableColors = [
    Color(0xFF3F51B5), // Indigo
    Color(0xFF009688), // Teal
    Colors.purple,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.indigo,
    Colors.green,
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
      _healthCondition = prefs.getString(_healthConditionKey) ?? '';
      
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
      await prefs.setString(_healthConditionKey, _healthCondition);
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

  Future<void> setHealthCondition(String value) async {
    _healthCondition = value;
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
    _healthCondition = '';
    await _savePreferences();
    notifyListeners();
  }
  
  // Get theme data based on current preferences
  ThemeData getThemeData() {
    final lightBackground = const Color(0xFFEAF6FA); // Soft light blue
    final darkBackground = const Color(0xFF181C1F); // Deep dark blue/gray
    final lightCard = Colors.white;
    final darkCard = const Color(0xFF232A34);
    final lightText = const Color(0xFF212121);
    final darkText = Colors.white;
    final lightIcon = const Color(0xFF3F51B5);
    final darkIcon = const Color(0xFF80CBC4);

    final baseTheme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    return baseTheme.copyWith(
      scaffoldBackgroundColor: _isDarkMode ? darkBackground : lightBackground,
      cardColor: _isDarkMode ? darkCard : lightCard,
      primaryColor: _primaryColor,
      colorScheme: baseTheme.colorScheme.copyWith(
        primary: _primaryColor,
        secondary: _accentColor,
        background: _isDarkMode ? darkBackground : lightBackground,
        surface: _isDarkMode ? darkCard : lightCard,
        error: const Color(0xFFD32F2F),
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      textTheme: baseTheme.textTheme.apply(
        fontSizeFactor: _fontSize,
        bodyColor: _isDarkMode ? darkText : lightText,
        displayColor: _isDarkMode ? darkText : lightText,
      ),
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        titleTextStyle: baseTheme.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: _isDarkMode ? darkCard : lightCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 4,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
      ),
      iconTheme: IconThemeData(
        color: _isDarkMode ? darkIcon : lightIcon,
        size: 28,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _isDarkMode ? darkCard : lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(
          color: _isDarkMode ? Colors.white70 : Colors.black45,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _isDarkMode ? darkCard : lightCard,
        selectedItemColor: _accentColor,
        unselectedItemColor: _isDarkMode ? Colors.white54 : Colors.black38,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
} 