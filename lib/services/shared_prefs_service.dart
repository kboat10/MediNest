import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsService {
  static const String _keyName = 'user_name';
  static const String _keyAge = 'user_age';
  static const String _keyCondition = 'user_condition';
  static const String _keyReminders = 'user_reminders';

  static Future<void> saveUserData({
    required String name,
    required String age,
    required String condition,
    required String reminders,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    await prefs.setString(_keyAge, age);
    await prefs.setString(_keyCondition, condition);
    await prefs.setString(_keyReminders, reminders);
  }

  static Future<Map<String, String?>> loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString(_keyName),
      'age': prefs.getString(_keyAge),
      'condition': prefs.getString(_keyCondition),
      'reminders': prefs.getString(_keyReminders),
    };
  }

  static Future<bool> isUserOnboarded() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_keyName);
  }

  static Future<void> clearUserData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyAge);
    await prefs.remove(_keyCondition);
    await prefs.remove(_keyReminders);
  }
} 