import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/medication.dart';
import '../models/log_entry.dart';
import '../models/appointment.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';

class HealthDataProvider extends ChangeNotifier {
  // State variables
  bool _isLoading = false;
  String? _errorMessage;
  List<Medication>? _medications;
  List<LogEntry>? _logs;
  List<Appointment>? _appointments;
  Map<String, int> _waterIntake = {};
  Map<String, List<int>> _bloodPressure = {};
  Map<String, int> _bloodSugar = {};
  Map<String, int> _peakFlow = {};
  Map<String, int> _painLevel = {}; // Add pain level tracking
  UserProfile? _userProfile;
  StreamSubscription? _profileSubscription;
  
  // Streak tracking data
  Map<String, bool> _dailyMedicationCompletionStatus = {}; // date -> all meds taken
  int _currentStreak = 0;
  int _longestStreak = 0;

  // Services
  AuthService? _auth;
  FirestoreService? _firestore;
  StreamSubscription? _medicationSubscription;
  StreamSubscription? _appointmentSubscription;
  StreamSubscription? _logSubscription;
  StreamSubscription? _healthDataSubscription;

  // SharedPreferences keys
  static const String _medicationsKey = 'medications';
  static const String _logsKey = 'logs';
  static const String _appointmentsKey = 'appointments';
  
  // Constructor - initialize with local data immediately
  HealthDataProvider() {
    print('HealthDataProvider - Constructor called, initializing...');
    _initializeWithLocalData();
  }

  // Method to initialize services (called from screens that need them)
  void initializeServices(AuthService auth, FirestoreService firestore) {
    print('HealthDataProvider - initializeServices called');
    _auth = auth;
    _firestore = firestore;
    
    // Ensure loading state is false initially
    _setLoading(false);
    
    // DISABLED: Firestore connections to avoid errors
    // If user is authenticated, we'll use SharedPreferences only
    if (auth.currentUser != null) {
      print('HealthDataProvider - User authenticated, using SharedPreferences only');
      // Load any existing data from SharedPreferences
      loadAllDataFromSharedPreferences().then((_) {
        print('HealthDataProvider - ✅ Data loaded from SharedPreferences');
        notifyListeners();
      });
    }
  }

  // Initialize with local data immediately on startup
  Future<void> _initializeWithLocalData() async {
    try {
      print('HealthDataProvider - Loading initial data from SharedPreferences...');
      await loadAllDataFromSharedPreferences();
      
      // Ensure we have at least empty lists
      _medications ??= [];
      _appointments ??= [];
      _logs ??= [];
      
      print('HealthDataProvider - ✅ Initialized with local data');
      print('HealthDataProvider - Medications: ${_medications!.length}');
      print('HealthDataProvider - Appointments: ${_appointments!.length}');
      print('HealthDataProvider - Logs: ${_logs!.length}');
      
      // Ensure loading state is false after initialization
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      print('HealthDataProvider - Error in initial local data load: $e');
      // Set default empty state
      _medications = [];
      _appointments = [];
      _logs = [];
      
      // Ensure loading state is false even on error
      _setLoading(false);
      notifyListeners();
    }
  }

  // Method to check if data exists in SharedPreferences
  Future<bool> hasDataInSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasMedications = prefs.getString(_medicationsKey) != null;
      final hasAppointments = prefs.getString(_appointmentsKey) != null;
      final hasLogs = prefs.getString(_logsKey) != null;
      
      print('HealthDataProvider - Data check: medications=$hasMedications, appointments=$hasAppointments, logs=$hasLogs');
      
      // Debug: Print actual data if it exists
      if (hasMedications) {
        final medicationsJson = prefs.getString(_medicationsKey);
        print('HealthDataProvider - Medications JSON: $medicationsJson');
      }
      if (hasAppointments) {
        final appointmentsJson = prefs.getString(_appointmentsKey);
        print('HealthDataProvider - Appointments JSON: $appointmentsJson');
      }
      if (hasLogs) {
        final logsJson = prefs.getString(_logsKey);
        print('HealthDataProvider - Logs JSON: $logsJson');
      }
      
      return hasMedications || hasAppointments || hasLogs;
    } catch (e) {
      print('HealthDataProvider - Error checking data existence: $e');
      return false;
    }
  }
  
  // Getters are here...
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Medication> get medications => _medications ?? [];
  List<LogEntry> get logs => _logs ?? [];
  List<Appointment> get appointments => _appointments ?? [];
  UserProfile? get userProfile => _userProfile;
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;

  Medication? get nextMedication {
    if (_medications == null || _medications!.isEmpty) return null;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Convert medications to list with parsed times
    final medicationsWithTimes = _medications!.map((med) {
      final timeStr = med.reminderTime ?? med.time;
      final parsedTime = _parseTimeString(timeStr);
      final todayScheduledTime = DateTime(today.year, today.month, today.day, parsedTime.hour, parsedTime.minute);
      
      return {
        'medication': med,
        'scheduledTime': todayScheduledTime,
        'timeStr': timeStr,
      };
    }).toList();
    
    // First, try to find upcoming medications today
    final upcomingToday = medicationsWithTimes
        .where((item) => (item['scheduledTime'] as DateTime).isAfter(now))
        .toList();
    
    if (upcomingToday.isNotEmpty) {
      // Sort by time and return the earliest upcoming medication today
      upcomingToday.sort((a, b) => (a['scheduledTime'] as DateTime).compareTo(b['scheduledTime'] as DateTime));
      return upcomingToday.first['medication'] as Medication;
    }
    
    // If no upcoming medications today, return the earliest medication for tomorrow
    medicationsWithTimes.sort((a, b) => (a['scheduledTime'] as DateTime).compareTo(b['scheduledTime'] as DateTime));
    return medicationsWithTimes.first['medication'] as Medication;
  }
  
  // Helper method to parse time string (e.g., "08:30 AM" -> TimeOfDay)
  TimeOfDay _parseTimeString(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timePart = parts[0];
      final period = parts.length > 1 ? parts[1].toUpperCase() : 'AM';
      
      final timeParts = timePart.split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      
      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      // Fallback to 8:00 AM if parsing fails
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }
  int get missedDoses => _logs?.where((l) => l.type == 'medication' && l.description.startsWith('Missed')).length ?? 0;
  int get weeklyAppointments => _appointments?.where((a) => a.dateTime.isAfter(DateTime.now()) && a.dateTime.isBefore(DateTime.now().add(Duration(days: 7)))).length ?? 0;

  // Returns the current medication streak
  int get medicationStreak => _currentStreak;

  // Returns a list of upcoming appointments (next 5, sorted by date)
  List<Appointment> get upcomingAppointments {
    final now = DateTime.now();
    if (_appointments == null) return [];
    final upcoming = _appointments!.where((a) => a.dateTime.isAfter(now)).toList();
    upcoming.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return upcoming.take(5).toList();
  }

  // 2. Add methods:
  int getWaterIntake(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _waterIntake[key] ?? 0;
  }
  
  int? getPainLevel(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _painLevel[key];
  }
  
  Future<void> setPainLevel(DateTime date, int level) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _painLevel[key] = level;
    await _savePainLevelData();
    notifyListeners();
  }
  
  Future<void> incrementWaterIntake(DateTime date) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _waterIntake[key] = (_waterIntake[key] ?? 0) + 1;
    await _saveWaterIntakeData();
    notifyListeners();
  }
  Future<void> decrementWaterIntake(DateTime date) async {
    final key = '${date.year}-${date.month}-${date.day}';
    if ((_waterIntake[key] ?? 0) > 0) {
      _waterIntake[key] = _waterIntake[key]! - 1;
      await _saveWaterIntakeData();
      notifyListeners();
    }
  }

  // Methods for BP
  List<int>? getBloodPressure(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _bloodPressure[key];
  }
  Future<void> setBloodPressure(DateTime date, int systolic, int diastolic) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _bloodPressure[key] = [systolic, diastolic];
    await _saveVitalData();
    notifyListeners();
  }

  // Methods for blood sugar
  int? getBloodSugar(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _bloodSugar[key];
  }
  Future<void> setBloodSugar(DateTime date, int value) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _bloodSugar[key] = value;
    await _saveVitalData();
    notifyListeners();
  }

  // Methods for peak flow
  int? getPeakFlow(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _peakFlow[key];
  }
  Future<void> setPeakFlow(DateTime date, int value) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _peakFlow[key] = value;
    await _saveVitalData();
    notifyListeners();
  }

  // Private methods to update loading and error states
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Method to handle errors gracefully and ensure local persistence
  void _handleError(String operation, dynamic error) {
    print('HealthDataProvider - Error in $operation: $error');
    _setError('Failed to $operation: ${error.toString()}');
    
    // Always ensure local data is saved even when Firestore fails
    _ensureImmediateLocalSave();
  }

  // Method to clear error and continue with local data
  void _clearErrorAndContinue() {
    _clearError();
    print('HealthDataProvider - Error cleared, continuing with local data');
  }

  // Method to handle Firestore errors gracefully
  void _handleFirestoreError(String operation, dynamic error) {
    print('HealthDataProvider - Firestore error in $operation: $error');
    
    // Don't show error to user for Firestore failures - just log and continue with local data
    print('HealthDataProvider - Continuing with local data after Firestore error');
    
    // Ensure local data is saved
    _ensureImmediateLocalSave();
    
    // Clear any existing error state
    _clearError();
  }

  // Method to ensure app never gets stuck due to Firestore issues
  void _ensureAppNeverStuck() {
    // If we've been loading for too long, force load from SharedPreferences
    if (_isLoading && _medications == null) {
      print('HealthDataProvider - App seems stuck, forcing local data load...');
      loadAllDataFromSharedPreferences().then((_) {
        _setLoading(false);
        _clearError();
        notifyListeners();
      });
    }
  }

  // Debug method to print current state
  void debugPrintState() {
    print('HealthDataProvider - Current State:');
    print('  - isLoading: $_isLoading');
    print('  - errorMessage: $_errorMessage');
    print('  - medications: ${_medications?.length ?? 'null'}');
    print('  - appointments: ${_appointments?.length ?? 'null'}');
    print('  - logs: ${_logs?.length ?? 'null'}');
    print('  - userProfile: ${_userProfile?.name ?? 'null'}');
  }

  // Data persistence methods
  Future<void> _loadData() async {
    try {
      _setLoading(true);
      _clearError();
      
      final prefs = await SharedPreferences.getInstance();
      
      // Load medications
      final medicationsJson = prefs.getString(_medicationsKey);
      if (medicationsJson != null) {
        final medicationsList = jsonDecode(medicationsJson) as List;
        _medications = medicationsList.map((medData) => Medication.fromJson(medData)).toList();
      }
      
      // Load logs
      final logsJson = prefs.getString(_logsKey);
      if (logsJson != null) {
        final logsList = jsonDecode(logsJson) as List;
        _logs = logsList.map((logData) => LogEntry.fromJson(logData)).toList();
      }
      
      // Load appointments
      final appointmentsJson = prefs.getString(_appointmentsKey);
      if (appointmentsJson != null) {
        final appointmentsList = jsonDecode(appointmentsJson) as List;
        _appointments = appointmentsList.map((aptData) => Appointment.fromJson(aptData)).toList();
      }
      
      // Load water intake
      final waterIntakeJson = prefs.getString('waterIntake');
      if (waterIntakeJson != null) {
        _waterIntake = Map<String, int>.from(jsonDecode(waterIntakeJson));
      }
      
      // Load blood pressure
      final bpJson = prefs.getString('bloodPressure');
      if (bpJson != null) {
        _bloodPressure = (jsonDecode(bpJson) as Map<String, dynamic>).map((k, v) => MapEntry(k, List<int>.from(v)));
      }
      // Load blood sugar
      final sugarJson = prefs.getString('bloodSugar');
      if (sugarJson != null) {
        _bloodSugar = Map<String, int>.from(jsonDecode(sugarJson));
      }

      // Load peak flow
      final peakFlowJson = prefs.getString('peakFlow');
      if (peakFlowJson != null) {
        _peakFlow = Map<String, int>.from(jsonDecode(peakFlowJson));
      }
      
      // Load streak data
      final streakDataJson = prefs.getString('streakData');
      if (streakDataJson != null) {
        final streakData = jsonDecode(streakDataJson);
        _dailyMedicationCompletionStatus = Map<String, bool>.from(streakData['completionStatus'] ?? {});
        _currentStreak = streakData['currentStreak'] ?? 0;
        _longestStreak = streakData['longestStreak'] ?? 0;
      }
      
      // Do NOT load default data if empty; leave empty after onboarding/clear
      notifyListeners();
    } catch (e) {
      _setError('Failed to load data: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  void _loadDefaultData() {
    _medications = [
      Medication(name: 'Aspirin', time: '8:00 AM', taken: false),
      Medication(name: 'Vitamin D', time: '12:00 PM', taken: true),
    ];
    _logs = [
      LogEntry(date: DateTime.now().subtract(Duration(days: 1)), description: 'Missed Aspirin', type: 'medication'),
      LogEntry(date: DateTime.now().subtract(Duration(days: 2)), description: 'Took Vitamin D', type: 'medication'),
    ];
    _appointments = [
      Appointment(title: 'Doctor Visit', dateTime: DateTime.now().add(Duration(days: 3)), location: 'Clinic', notes: 'Bring reports'),
    ];
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save medications
      if (_medications != null) {
        final medicationsJson = _medications!.map((med) => med.toJson()).toList();
        await prefs.setString(_medicationsKey, jsonEncode(medicationsJson));
      }
      
      // Save logs
      if (_logs != null) {
        final logsJson = _logs!.map((log) => log.toJson(forFirestore: false)).toList();
        await prefs.setString(_logsKey, jsonEncode(logsJson));
      }
      
      // Save appointments
      if (_appointments != null) {
        final appointmentsJson = _appointments!.map((appt) => appt.toJson(forFirestore: false)).toList();
        await prefs.setString(_appointmentsKey, jsonEncode(appointmentsJson));
      }

      // Save water intake and vital data separately
      await _saveWaterIntakeData();
      await _saveVitalData();
    } catch (e) {
      _setError('Failed to save data: ${e.toString()}');
    }
  }

  Future<void> _saveWaterIntakeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('waterIntake', jsonEncode(_waterIntake));
    } catch (e) {
      _setError('Failed to save water intake data: ${e.toString()}');
    }
  }

  Future<void> _saveVitalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bloodPressure', jsonEncode(_bloodPressure));
      await prefs.setString('bloodSugar', jsonEncode(_bloodSugar));
      await prefs.setString('peakFlow', jsonEncode(_peakFlow));
    } catch (e) {
      _setError('Failed to save vital data: ${e.toString()}');
    }
  }

  Future<void> _savePainLevelData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('painLevel', jsonEncode(_painLevel));
    } catch (e) {
      _setError('Failed to save pain level data: ${e.toString()}');
    }
  }

  Future<void> _saveStreakData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final streakData = {
        'completionStatus': _dailyMedicationCompletionStatus,
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
      };
      await prefs.setString('streakData', jsonEncode(streakData));
    } catch (e) {
      _setError('Failed to save streak data: ${e.toString()}');
    }
  }

  // Save health data to Firestore
  Future<void> _saveHealthDataToFirestore() async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null && _firestore != null) {
      try {
        final healthData = {
          'waterIntake': _waterIntake,
          'bloodPressure': _bloodPressure,
          'bloodSugar': _bloodSugar,
          'peakFlow': _peakFlow,
          'painLevel': _painLevel,
          'streakData': {
            'completionStatus': _dailyMedicationCompletionStatus,
            'currentStreak': _currentStreak,
            'longestStreak': _longestStreak,
          },
        };
        await _firestore!.saveHealthData(uid, healthData);
      } catch (e) {
        _setError('Failed to save health data to Firestore: ${e.toString()}');
      }
    }
  }

  // Calculate and update medication streaks
  Future<void> _updateMedicationStreaks() async {
    if (_medications == null || _medications!.isEmpty || _logs == null) return;

    // Build a map of date -> set of taken medication names
    final Map<DateTime, Set<String>> takenPerDay = {};
    for (final log in _logs!) {
      if (log.type == 'medication' && log.description.startsWith('Took ')) {
        final medName = log.description.substring(5);
        final date = DateTime(log.date.year, log.date.month, log.date.day);
        takenPerDay.putIfAbsent(date, () => {}).add(medName);
      }
    }

    // Get all medication names
    final allMedNames = _medications!.map((m) => m.name).toSet();
    
    // Update daily completion status
    final today = DateTime.now();
    for (int i = 0; i < 365; i++) { // Check last 365 days
      final checkDate = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
      final takenMeds = takenPerDay[checkDate] ?? {};
      
      // Only mark as complete if all medications were taken
      _dailyMedicationCompletionStatus[dateKey] = takenMeds.length == allMedNames.length && allMedNames.isNotEmpty;
    }

    // Calculate current streak (consecutive days from today backwards)
    _currentStreak = 0;
    DateTime checkDay = DateTime(today.year, today.month, today.day);
    
    while (true) {
      final dateKey = '${checkDay.year}-${checkDay.month}-${checkDay.day}';
      final isComplete = _dailyMedicationCompletionStatus[dateKey] ?? false;
      
      if (isComplete) {
        _currentStreak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Calculate longest streak
    int tempStreak = 0;
    int maxStreak = 0;
    
    // Sort dates and check for longest consecutive sequence
    final sortedDates = _dailyMedicationCompletionStatus.keys.toList()
      ..sort((a, b) {
        final partsA = a.split('-');
        final partsB = b.split('-');
        final dateA = DateTime(int.parse(partsA[0]), int.parse(partsA[1]), int.parse(partsA[2]));
        final dateB = DateTime(int.parse(partsB[0]), int.parse(partsB[1]), int.parse(partsB[2]));
        return dateA.compareTo(dateB);
      });

    DateTime? previousDate;
    for (final dateKey in sortedDates) {
      final isComplete = _dailyMedicationCompletionStatus[dateKey] ?? false;
      final parts = dateKey.split('-');
      final currentDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      
      if (isComplete) {
        if (previousDate != null && currentDate.difference(previousDate).inDays == 1) {
          tempStreak++;
        } else {
          tempStreak = 1;
        }
        maxStreak = maxStreak > tempStreak ? maxStreak : tempStreak;
        previousDate = currentDate;
      } else {
        tempStreak = 0;
        previousDate = null;
      }
    }
    
    _longestStreak = maxStreak > _longestStreak ? maxStreak : _longestStreak;
    
    // Save the updated streak data
    await _saveStreakData();
    await _saveHealthDataToFirestore();
    notifyListeners();
  }

  // Method to check if all medications were taken for a specific date
  bool isDayComplete(DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    return _dailyMedicationCompletionStatus[dateKey] ?? false;
  }

  // Export/Import functionality
  Future<String> exportData() async {
    try {
      final exportData = {
        'medications': (_medications ?? []).map((m) => m.toJson()).toList(),
        'logs': (_logs ?? []).map((l) => l.toJson()).toList(),
        'appointments': (_appointments ?? []).map((a) => a.toJson()).toList(),
        'waterIntake': _waterIntake,
        'bloodPressure': _bloodPressure,
        'bloodSugar': _bloodSugar,
        'peakFlow': _peakFlow,
        'streakData': {
          'completionStatus': _dailyMedicationCompletionStatus,
          'currentStreak': _currentStreak,
          'longestStreak': _longestStreak,
        },
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };
      
      return jsonEncode(exportData);
    } catch (e) {
      throw Exception('Failed to export data: ${e.toString()}');
    }
  }

  Future<void> importData(String jsonData) async {
    try {
      _setLoading(true);
      _clearError();
      
      final importData = jsonDecode(jsonData);
      
      // Validate version compatibility
      final version = importData['version'] ?? '1.0.0';
      if (version != '1.0.0') {
        throw Exception('Incompatible data version: $version');
      }
      
      // Import medications
      if (importData['medications'] != null) {
        _medications = (importData['medications'] as List)
            .map((json) => Medication.fromJson(json))
            .toList();
      }
      
      // Import logs
      if (importData['logs'] != null) {
        _logs = (importData['logs'] as List)
            .map((json) => LogEntry.fromJson(json))
            .toList();
      }
      
      // Import appointments
      if (importData['appointments'] != null) {
        _appointments = (importData['appointments'] as List)
            .map((json) => Appointment.fromJson(json))
            .toList();
      }

      // Import water intake
      if (importData['waterIntake'] != null) {
        _waterIntake = Map<String, int>.from(importData['waterIntake'] as Map);
      }

      // Import blood pressure
      if (importData['bloodPressure'] != null) {
        _bloodPressure = (importData['bloodPressure'] as Map).map((k, v) => MapEntry(k as String, List<int>.from(v)));
      }
      // Import blood sugar
      if (importData['bloodSugar'] != null) {
        _bloodSugar = Map<String, int>.from(importData['bloodSugar'] as Map);
      }

      // Import peak flow
      if (importData['peakFlow'] != null) {
        _peakFlow = Map<String, int>.from(importData['peakFlow'] as Map);
      }

      // Import streak data
      if (importData['streakData'] != null) {
        final streakData = importData['streakData'];
        _dailyMedicationCompletionStatus = Map<String, bool>.from(streakData['completionStatus'] ?? {});
        _currentStreak = streakData['currentStreak'] ?? 0;
        _longestStreak = streakData['longestStreak'] ?? 0;
      }
      
      // Save imported data
      await _saveData();
      await _saveStreakData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to import data: ${e.toString()}');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Backup and restore functionality
  Future<void> createBackup() async {
    try {
      _setLoading(true);
      _clearError();
      
      final backupData = await exportData();
      final prefs = await SharedPreferences.getInstance();
      
      // Store backup with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupKey = 'backup_$timestamp';
      await prefs.setString(backupKey, backupData);
      
      // Keep only last 5 backups
      final allKeys = prefs.getKeys().where((key) => key.startsWith('backup_')).toList();
      allKeys.sort((a, b) => int.parse(b.split('_')[1]).compareTo(int.parse(a.split('_')[1])));
      
      if (allKeys.length > 5) {
        for (int i = 5; i < allKeys.length; i++) {
          await prefs.remove(allKeys[i]);
        }
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to create backup: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> getBackups() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupKeys = prefs.getKeys().where((key) => key.startsWith('backup_')).toList();
      
      final backups = <Map<String, dynamic>>[];
      for (final key in backupKeys) {
        final timestamp = int.parse(key.split('_')[1]);
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        final data = prefs.getString(key);
        
        if (data != null) {
          final jsonData = jsonDecode(data);
          backups.add({
            'key': key,
            'date': date,
            'medicationCount': (jsonData['medications'] as List?)?.length ?? 0,
            'logCount': (jsonData['logs'] as List?)?.length ?? 0,
            'appointmentCount': (jsonData['appointments'] as List?)?.length ?? 0,
          });
        }
      }
      
      backups.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      return backups;
    } catch (e) {
      _setError('Failed to get backups: ${e.toString()}');
      return [];
    }
  }

  Future<void> restoreBackup(String backupKey) async {
    try {
      _setLoading(true);
      _clearError();
      
      final prefs = await SharedPreferences.getInstance();
      final backupData = prefs.getString(backupKey);
      
      if (backupData == null) {
        throw Exception('Backup not found');
      }
      
      await importData(backupData);
      notifyListeners();
    } catch (e) {
      _setError('Failed to restore backup: ${e.toString()}');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteBackup(String backupKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(backupKey);
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete backup: ${e.toString()}');
    }
  }

  // Public methods with error handling
  Future<void> markMedicationAsTaken(int index) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _medications![index] = _medications![index].copyWith(taken: true);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to mark medication as taken: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> markMedicationAsMissed(int index) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _medications![index] = _medications![index].copyWith(taken: false);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to mark medication as missed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Method to ensure immediate local persistence of all data
  Future<void> _ensureImmediateLocalSave() async {
    try {
      print('HealthDataProvider - Ensuring immediate local save of all data...');
      await saveAllDataToSharedPreferences();
      print('HealthDataProvider - ✅ All data immediately saved to SharedPreferences');
    } catch (e) {
      print('HealthDataProvider - Error in immediate local save: $e');
    }
  }

  // DISABLED: Enhanced update method that loads from SharedPreferences first
  void update(AuthService auth, FirestoreService firestore) {
    print('HealthDataProvider - update method disabled, using initializeServices instead');
    // Do nothing - use initializeServices method instead
  }

  // DISABLED: Firestore connections to avoid errors
  void _attemptFirestoreConnections() {
    print('HealthDataProvider - Firestore connections disabled, using SharedPreferences only');
    // Do nothing - all data will be managed through SharedPreferences
  }

  @override
  void dispose() {
    _medicationSubscription?.cancel();
    _appointmentSubscription?.cancel();
    _logSubscription?.cancel();
    _profileSubscription?.cancel();
    _healthDataSubscription?.cancel();
    super.dispose();
  }

  Future<Medication> addMedication(Medication medication) async {
    try {
    final uid = _auth?.currentUser?.uid;
      if (uid == null) {
        print('HealthDataProvider - No current user, cannot add medication');
        return medication;
      }
      
      // Add to local list first
      _medications ??= [];
      final newMedication = medication.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
      _medications!.add(newMedication);
      
      // Save to SharedPreferences immediately
      await saveAllDataToSharedPreferences();
      print('HealthDataProvider - Added medication to SharedPreferences: ${medication.name}');
      
      // Update streaks
      _updateMedicationStreaks();
      
      notifyListeners();
      return newMedication;
    } catch (e) {
      print('HealthDataProvider - Error adding medication: $e');
      return medication;
    }
  }

  Future<void> updateMedication(String docId, Medication medication) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      try {
        // Update local list
        final index = _medications?.indexWhere((med) => med.id == docId);
        if (index != null && index >= 0) {
          _medications![index] = medication;
          await saveAllDataToSharedPreferences();
          print('HealthDataProvider - Updated medication in SharedPreferences: ${medication.name}');
        }
        
        notifyListeners();
      } catch (e) {
        print('HealthDataProvider - Error updating medication: $e');
      }
    }
  }

  Future<void> deleteMedication(String docId) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      try {
        // Remove from local list
        _medications?.removeWhere((med) => med.id == docId);
        await saveAllDataToSharedPreferences();
        print('HealthDataProvider - Deleted medication from SharedPreferences');
        
        notifyListeners();
      } catch (e) {
        print('HealthDataProvider - Error deleting medication: $e');
      }
    }
  }

  Future<Appointment> addAppointment(Appointment appointment) async {
    try {
    final uid = _auth?.currentUser?.uid;
      if (uid == null) {
        print('HealthDataProvider - No current user, cannot add appointment');
        return appointment;
      }
      
      // Add to local list first
      _appointments ??= [];
      final newAppointment = appointment.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
      _appointments!.add(newAppointment);
      
      // Save to SharedPreferences immediately
      await saveAllDataToSharedPreferences();
      print('HealthDataProvider - Added appointment to SharedPreferences: ${appointment.title}');
      
      notifyListeners();
      return newAppointment;
    } catch (e) {
      print('HealthDataProvider - Error adding appointment: $e');
      return appointment;
    }
  }

  Future<void> editAppointment(String docId, Appointment appointment) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      try {
        // Update local list
        final index = _appointments?.indexWhere((apt) => apt.id == docId);
        if (index != null && index >= 0) {
          _appointments![index] = appointment;
          await saveAllDataToSharedPreferences();
          print('HealthDataProvider - Updated appointment in SharedPreferences: ${appointment.title}');
        }
        
        notifyListeners();
      } catch (e) {
        print('HealthDataProvider - Error updating appointment: $e');
      }
    }
  }

  Future<void> deleteAppointment(String docId) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      try {
        // Remove from local list
        _appointments?.removeWhere((apt) => apt.id == docId);
        await saveAllDataToSharedPreferences();
        print('HealthDataProvider - Deleted appointment from SharedPreferences');
        
        notifyListeners();
      } catch (e) {
        print('HealthDataProvider - Error deleting appointment: $e');
      }
    }
  }

  Future<LogEntry> addLog(LogEntry log) async {
    try {
      print('HealthDataProvider - addLog called with: ${log.description}');
      final uid = _auth?.currentUser?.uid;
      if (uid == null) {
        print('HealthDataProvider - No current user, cannot add log');
        return log;
      }
      
      // Add to local list first
      _logs ??= [];
      final newLog = log.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
      _logs!.add(newLog);
      
      print('HealthDataProvider - Added log to local list. Total logs: ${_logs!.length}');
      print('HealthDataProvider - New log: ${newLog.description} | Date: ${newLog.date.toIso8601String()} | ID: ${newLog.id}');
      
      // Save to SharedPreferences immediately
      await saveAllDataToSharedPreferences();
      print('HealthDataProvider - Added log to SharedPreferences: ${log.description}');
      
      // Update streaks
      _updateMedicationStreaks();
      
      notifyListeners();
      print('HealthDataProvider - Notified listeners after adding log');
      return newLog;
    } catch (e) {
      print('HealthDataProvider - Error adding log: $e');
      return log;
    }
  }

  Future<void> editLog(String docId, LogEntry log) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      try {
        // Update local list
        final index = _logs?.indexWhere((l) => l.id == docId);
        if (index != null && index >= 0) {
          _logs![index] = log;
          await saveAllDataToSharedPreferences();
          print('HealthDataProvider - Updated log in SharedPreferences: ${log.description}');
        }
        
        notifyListeners();
      } catch (e) {
        print('HealthDataProvider - Error updating log: $e');
      }
    }
  }

  Future<void> deleteLog(String docId) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      try {
        // Remove from local list
        _logs?.removeWhere((l) => l.id == docId);
        await saveAllDataToSharedPreferences();
        print('HealthDataProvider - Deleted log from SharedPreferences');
        
        notifyListeners();
      } catch (e) {
        print('HealthDataProvider - Error deleting log: $e');
      }
    }
  }

  // Search and filter functionality
  List<Medication> searchMedications(String query) {
    if (query.isEmpty) return _medications ?? [];
    return (_medications ?? []).where((med) => 
      med.name.toLowerCase().contains(query.toLowerCase()) ||
      med.time.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<LogEntry> searchLogs(String query) {
    if (query.isEmpty) return _logs ?? [];
    return (_logs ?? []).where((log) => 
      log.description.toLowerCase().contains(query.toLowerCase()) ||
      log.type.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<Appointment> searchAppointments(String query) {
    if (query.isEmpty) return _appointments ?? [];
    return (_appointments ?? []).where((appt) => 
      appt.title.toLowerCase().contains(query.toLowerCase()) ||
      appt.location.toLowerCase().contains(query.toLowerCase()) ||
      appt.notes.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  // Edit functionality
  Future<void> editMedication(int index, String name, String time, [String? reminderTime]) async {
    try {
      _setLoading(true);
      _clearError();
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      _medications![index] = _medications![index].copyWith(
        name: name,
        time: time,
        reminderTime: reminderTime,
      );
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to edit medication:  [0m${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addDailyFeelingLog(DateTime date, String feeling, List<String> symptoms) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Add to local list first
      _logs ??= [];
      final newLog = LogEntry(
        date: date,
        description: 'Daily feeling and symptoms',
        type: 'daily',
        feeling: feeling,
        symptoms: symptoms,
      );
      _logs!.add(newLog);
      
      // Save to SharedPreferences immediately
      await _ensureImmediateLocalSave();
      print('HealthDataProvider - Added daily feeling log to SharedPreferences');
      
      // Try to save to Firestore (non-blocking)
      final uid = _auth?.currentUser?.uid;
      if (uid != null && _firestore != null) {
        try {
          final docRef = await _firestore!.addLog(newLog, uid);
          print('HealthDataProvider - Successfully added daily feeling log to Firestore');
        } catch (e) {
          print('HealthDataProvider - Firestore add daily feeling log failed: $e');
          // Continue with local data since Firestore failed
        }
      }
      
      notifyListeners();
    } catch (e) {
      _setError('Failed to add daily feeling log: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Method to clear error message
  void clearError() {
    _clearError();
  }

  // Method to reload data
  Future<void> loadData() async {
    await _loadData();
  }

  // Method to clear all health data
  Future<void> clearAllData() async {
    try {
      _setLoading(true);
      _clearError();
      _medications?.clear();
      _logs?.clear();
      _appointments?.clear();
      _waterIntake.clear(); // Clear water intake data
      _bloodPressure.clear();
      _bloodSugar.clear();
      _peakFlow.clear(); // Clear peak flow data
      _dailyMedicationCompletionStatus.clear(); // Clear streak data
      _currentStreak = 0;
      _longestStreak = 0;
      await _saveData();
      await _saveStreakData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUserProfile(UserProfile profile) async {
    try {
      print('HealthDataProvider - updateUserProfile called for user: ${profile.email}');
      
      // Update local profile immediately
      _userProfile = profile;
      notifyListeners();
      
      // Save to SharedPreferences immediately
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', profile.name);
      if (profile.age != null) {
        await prefs.setString('user_age', profile.age!);
      }
      if (profile.healthCondition != null) {
        await prefs.setString('user_condition', profile.healthCondition!);
      }
      print('HealthDataProvider - Profile saved to SharedPreferences');
      
      print('HealthDataProvider - Profile update completed successfully');
    } catch (e) {
      print('HealthDataProvider - Error updating user profile: $e');
      throw e;
    }
  }

  // Create a default profile for users who don't have one
  Future<void> _createDefaultProfile(User user) async {
    try {
      // Get all onboarding data
      final prefs = await SharedPreferences.getInstance();
      final onboardingName = prefs.getString('user_name') ?? '';
      final onboardingAge = prefs.getString('user_age');
      final onboardingCondition = prefs.getString('user_condition');
      
      final defaultProfile = UserProfile(
        uid: user.uid,
        name: onboardingName.isNotEmpty ? onboardingName : (user.displayName ?? ''),
        email: user.email ?? '',
        age: onboardingAge,
        healthCondition: onboardingCondition,
        createdAt: DateTime.now(),
      );
      
      // Save to SharedPreferences instead of Firestore
      await updateUserProfile(defaultProfile);
      print('HealthDataProvider - Default profile created and saved to SharedPreferences');
    } catch (e) {
      print('HealthDataProvider - Error creating default profile: $e');
      // Don't set error state for profile creation failures
    }
  }

  // Load medications from SharedPreferences as fallback
  Future<void> loadMedicationsFromSharedPreferences() async {
    try {
      print('HealthDataProvider - Loading medications from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final medicationsJson = prefs.getString('medications');
      
      if (medicationsJson != null) {
        final medicationsList = jsonDecode(medicationsJson) as List;
        _medications = medicationsList.map((medData) => Medication.fromJson(medData)).toList();
        
        print('HealthDataProvider - Loaded ${_medications!.length} medications from SharedPreferences');
        notifyListeners();
      }
    } catch (e) {
      print('HealthDataProvider - Error loading medications from SharedPreferences: $e');
    }
  }

  // Load user profile from SharedPreferences as fallback
  Future<void> loadUserProfileFromSharedPreferences() async {
    try {
      print('HealthDataProvider - Loading user profile from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      
      final name = prefs.getString('user_name');
      final age = prefs.getString('user_age');
      final condition = prefs.getString('user_condition');
      
      if (name != null && _auth?.currentUser != null) {
        _userProfile = UserProfile(
          uid: _auth!.currentUser!.uid,
          name: name,
          email: _auth!.currentUser!.email ?? '',
          age: age,
          healthCondition: condition,
          createdAt: DateTime.now(),
        );
        
        print('HealthDataProvider - Loaded user profile from SharedPreferences: ${_userProfile!.name}');
        notifyListeners();
      }
    } catch (e) {
      print('HealthDataProvider - Error loading user profile from SharedPreferences: $e');
    }
  }

  // Save all health data to SharedPreferences
  Future<void> saveAllDataToSharedPreferences() async {
    try {
      print('HealthDataProvider - Saving all health data to SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      
      // Save medications
      if (_medications != null) {
        final medicationsJson = _medications!.map((med) => med.toJson()).toList();
        await prefs.setString(_medicationsKey, jsonEncode(medicationsJson));
        print('HealthDataProvider - Saved ${_medications!.length} medications to SharedPreferences');
      }
      
      // Save appointments
      if (_appointments != null) {
        final appointmentsJson = _appointments!.map((apt) => apt.toJson()).toList();
        await prefs.setString(_appointmentsKey, jsonEncode(appointmentsJson));
        print('HealthDataProvider - Saved ${_appointments!.length} appointments to SharedPreferences');
      }
      
      // Save logs
      if (_logs != null) {
        final logsJson = _logs!.map((log) => log.toJson(forFirestore: false)).toList();
        await prefs.setString(_logsKey, jsonEncode(logsJson));
        print('HealthDataProvider - Saved ${_logs!.length} logs to SharedPreferences');
      }
      
      // Save water intake
      if (_waterIntake.isNotEmpty) {
        await prefs.setString('waterIntake', jsonEncode(_waterIntake));
        print('HealthDataProvider - Saved water intake data to SharedPreferences');
      }
      
      // Save blood pressure
      if (_bloodPressure.isNotEmpty) {
        await prefs.setString('bloodPressure', jsonEncode(_bloodPressure));
        print('HealthDataProvider - Saved blood pressure data to SharedPreferences');
      }
      
      // Save blood sugar
      if (_bloodSugar.isNotEmpty) {
        await prefs.setString('bloodSugar', jsonEncode(_bloodSugar));
        print('HealthDataProvider - Saved blood sugar data to SharedPreferences');
      }
      
      // Save peak flow
      if (_peakFlow.isNotEmpty) {
        await prefs.setString('peakFlow', jsonEncode(_peakFlow));
        print('HealthDataProvider - Saved peak flow data to SharedPreferences');
      }

      // Save pain level
      if (_painLevel.isNotEmpty) {
        await prefs.setString('painLevel', jsonEncode(_painLevel));
        print('HealthDataProvider - Saved pain level data to SharedPreferences');
      }
      
      // Save streak data
      final streakData = {
        'completionStatus': _dailyMedicationCompletionStatus,
        'currentStreak': _currentStreak,
        'longestStreak': _longestStreak,
      };
      await prefs.setString('streakData', jsonEncode(streakData));
      print('HealthDataProvider - Saved streak data to SharedPreferences');
      
      print('HealthDataProvider - ✅ All health data saved to SharedPreferences');
    } catch (e) {
      print('HealthDataProvider - Error saving all data to SharedPreferences: $e');
    }
  }

  // Load all health data from SharedPreferences
  Future<void> loadAllDataFromSharedPreferences() async {
    try {
      print('HealthDataProvider - Loading all health data from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      
      // Load medications
      final medicationsJson = prefs.getString(_medicationsKey);
      if (medicationsJson != null) {
        final medicationsList = jsonDecode(medicationsJson) as List;
        _medications = medicationsList.map((medData) => Medication.fromJson(medData)).toList();
        print('HealthDataProvider - Loaded ${_medications!.length} medications from SharedPreferences');
      }
      
      // Load appointments
      final appointmentsJson = prefs.getString(_appointmentsKey);
      if (appointmentsJson != null) {
        final appointmentsList = jsonDecode(appointmentsJson) as List;
        _appointments = appointmentsList.map((aptData) => Appointment.fromJson(aptData)).toList();
        print('HealthDataProvider - Loaded ${_appointments!.length} appointments from SharedPreferences');
      }
      
      // Load logs
      final logsJson = prefs.getString(_logsKey);
      if (logsJson != null) {
        final logsList = jsonDecode(logsJson) as List;
        _logs = logsList.map((logData) => LogEntry.fromJson(logData)).toList();
        print('HealthDataProvider - Loaded ${_logs!.length} logs from SharedPreferences');
      }
      
      // Load user profile from SharedPreferences
      final name = prefs.getString('user_name');
      final age = prefs.getString('user_age');
      final condition = prefs.getString('user_condition');
      
      if (name != null && _auth?.currentUser != null) {
        _userProfile = UserProfile(
          uid: _auth!.currentUser!.uid,
          name: name,
          email: _auth!.currentUser!.email ?? '',
          age: age,
          healthCondition: condition,
          createdAt: DateTime.now(),
        );
        print('HealthDataProvider - Loaded user profile from SharedPreferences: ${_userProfile!.name}');
      }
      
      // Load water intake
      final waterIntakeJson = prefs.getString('waterIntake');
      if (waterIntakeJson != null) {
        _waterIntake = Map<String, int>.from(jsonDecode(waterIntakeJson));
        print('HealthDataProvider - Loaded water intake data from SharedPreferences');
      }
      
      // Load blood pressure
      final bloodPressureJson = prefs.getString('bloodPressure');
      if (bloodPressureJson != null) {
        _bloodPressure = Map<String, List<int>>.from(jsonDecode(bloodPressureJson));
        print('HealthDataProvider - Loaded blood pressure data from SharedPreferences');
      }
      
      // Load blood sugar
      final bloodSugarJson = prefs.getString('bloodSugar');
      if (bloodSugarJson != null) {
        _bloodSugar = Map<String, int>.from(jsonDecode(bloodSugarJson));
        print('HealthDataProvider - Loaded blood sugar data from SharedPreferences');
      }
      
      // Load peak flow
      final peakFlowJson = prefs.getString('peakFlow');
      if (peakFlowJson != null) {
        _peakFlow = Map<String, int>.from(jsonDecode(peakFlowJson));
        print('HealthDataProvider - Loaded peak flow data from SharedPreferences');
      }
      
      // Load pain level
      final painLevelJson = prefs.getString('painLevel');
      if (painLevelJson != null) {
        _painLevel = Map<String, int>.from(jsonDecode(painLevelJson));
        print('HealthDataProvider - Loaded pain level data from SharedPreferences');
      }
      
      // Load streak data
      final streakDataJson = prefs.getString('streakData');
      if (streakDataJson != null) {
        final streakData = jsonDecode(streakDataJson);
        _dailyMedicationCompletionStatus = Map<String, bool>.from(streakData['completionStatus'] ?? {});
        _currentStreak = streakData['currentStreak'] ?? 0;
        _longestStreak = streakData['longestStreak'] ?? 0;
        print('HealthDataProvider - Loaded streak data from SharedPreferences');
      }
      
      print('HealthDataProvider - ✅ All health data loaded from SharedPreferences');
      notifyListeners();
    } catch (e) {
      print('HealthDataProvider - Error loading all data from SharedPreferences: $e');
    }
  }

  // Load appointments from SharedPreferences as fallback
  Future<void> loadAppointmentsFromSharedPreferences() async {
    try {
      print('HealthDataProvider - Loading appointments from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final appointmentsJson = prefs.getString('appointments');
      
      if (appointmentsJson != null) {
        final appointmentsList = jsonDecode(appointmentsJson) as List;
        _appointments = appointmentsList.map((aptData) => Appointment.fromJson(aptData)).toList();
        print('HealthDataProvider - Loaded ${_appointments!.length} appointments from SharedPreferences');
        notifyListeners();
      }
    } catch (e) {
      print('HealthDataProvider - Error loading appointments from SharedPreferences: $e');
    }
  }

  // Load logs from SharedPreferences as fallback
  Future<void> loadLogsFromSharedPreferences() async {
    try {
      print('HealthDataProvider - Loading logs from SharedPreferences...');
      final prefs = await SharedPreferences.getInstance();
      final logsJson = prefs.getString(_logsKey);
      
      if (logsJson != null) {
        final logsList = jsonDecode(logsJson) as List;
        _logs = logsList.map((logData) => LogEntry.fromJson(logData)).toList();
        print('HealthDataProvider - Loaded ${_logs!.length} logs from SharedPreferences');
        notifyListeners();
      }
    } catch (e) {
      print('HealthDataProvider - Error loading logs from SharedPreferences: $e');
    }
  }

  // Update medication streak tracking
  Future<void> updateMedicationStreak(DateTime date) async {
    try {
      print('HealthDataProvider - Updating medication streak for date: ${date.toIso8601String()}');
      
      // Get all medications for the user
      final userMedications = _medications ?? [];
      if (userMedications.isEmpty) {
        print('HealthDataProvider - No medications found, skipping streak update');
        return;
      }
      
      // Get all medication logs for the given date
      final dateKey = '${date.year}-${date.month}-${date.day}';
      final medicationLogsForDate = _logs?.where((log) => 
        log.type == 'medication' &&
        log.date.year == date.year &&
        log.date.month == date.month &&
        log.date.day == date.day
      ).toList() ?? [];
      
      // Check if all medications were taken on this date
      final takenMedications = medicationLogsForDate
          .where((log) => log.description.startsWith('Took'))
          .map((log) => log.description.replaceFirst('Took ', ''))
          .toSet();
      
      final allMedicationNames = userMedications.map((med) => med.name).toSet();
      final allTaken = allMedicationNames.every((medName) => takenMedications.contains(medName));
      
      // Update completion status for this date
      _dailyMedicationCompletionStatus[dateKey] = allTaken;
      
      // Recalculate streaks
      _recalculateStreaks();
      
      // Save updated streak data
      await _saveStreakData();
      await saveAllDataToSharedPreferences();
      
      print('HealthDataProvider - Streak updated: allTaken=$allTaken, currentStreak=$_currentStreak, longestStreak=$_longestStreak');
      notifyListeners();
    } catch (e) {
      print('HealthDataProvider - Error updating medication streak: $e');
    }
  }

  // Recalculate medication streaks
  void _recalculateStreaks() {
    try {
      print('HealthDataProvider - Recalculating medication streaks...');
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      int currentStreak = 0;
      int longestStreak = _longestStreak;
      
      // Check consecutive days backwards from today
      for (int i = 0; i < 365; i++) { // Check up to 1 year back
        final checkDate = today.subtract(Duration(days: i));
        final dateKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        
        if (_dailyMedicationCompletionStatus[dateKey] == true) {
          currentStreak++;
        } else {
          break; // Streak broken
        }
      }
      
      _currentStreak = currentStreak;
      
      // Update longest streak if current is longer
      if (currentStreak > longestStreak) {
        longestStreak = currentStreak;
        _longestStreak = longestStreak;
      }
      
      print('HealthDataProvider - Streak calculation complete: current=$currentStreak, longest=$longestStreak');
    } catch (e) {
      print('HealthDataProvider - Error recalculating streaks: $e');
    }
  }

  // Handle user logout - clear data and save empty state
  void handleUserLogout() {
    print('HealthDataProvider - Handling user logout');
    
    // Cancel all subscriptions
    _medicationSubscription?.cancel();
    _appointmentSubscription?.cancel();
    _logSubscription?.cancel();
    _profileSubscription?.cancel();
    _healthDataSubscription?.cancel();
    
    // Clear all data
    _medications = [];
    _appointments = [];
    _logs = [];
    _userProfile = null;
    _waterIntake.clear();
    _bloodPressure.clear();
    _bloodSugar.clear();
    _peakFlow.clear();
    _painLevel.clear();
    _dailyMedicationCompletionStatus.clear();
    _currentStreak = 0;
    _longestStreak = 0;
    
    // Clear error state
    _clearError();
    
    // Save empty state to SharedPreferences
    _ensureImmediateLocalSave();
    
    notifyListeners();
    print('HealthDataProvider - User logout handled, data cleared');
  }

  // Method to ensure app is always ready with local data
  Future<void> ensureLocalDataReady() async {
    try {
      print('HealthDataProvider - Ensuring local data is ready...');
      
      // If we don't have data loaded yet, load from SharedPreferences
      if (_medications == null || _appointments == null || _logs == null) {
        print('HealthDataProvider - Loading missing data from SharedPreferences...');
        await loadAllDataFromSharedPreferences();
      }
      
      // Ensure we have at least empty lists if no data exists
      _medications ??= [];
      _appointments ??= [];
      _logs ??= [];
      
      // Load user profile from SharedPreferences if not available
      if (_userProfile == null && _auth?.currentUser != null) {
        print('HealthDataProvider - Loading user profile from SharedPreferences...');
        await loadUserProfileFromSharedPreferences();
      }
      
      print('HealthDataProvider - ✅ Local data is ready');
      notifyListeners();
    } catch (e) {
      print('HealthDataProvider - Error ensuring local data ready: $e');
      // Set default empty state
      _medications ??= [];
      _appointments ??= [];
      _logs ??= [];
      notifyListeners();
    }
  }

  // Method to manually sync all data to Firestore
  Future<void> syncDataToFirestore(UserProfile userProfile) async {
    try {
      print('HealthDataProvider - Starting manual sync to Firestore...');
      _setLoading(true);
      _clearError();
      
      final uid = _auth?.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }
      
      if (_firestore == null) {
        throw Exception('Firestore service not available');
      }
      
      // Save user profile first
      print('HealthDataProvider - Syncing user profile...');
      await _firestore!.setUserProfile(userProfile);
      
      // Sync medications
      print('HealthDataProvider - Syncing medications...');
      for (final medication in _medications ?? []) {
        try {
          await _firestore!.addMedication(medication, uid);
        } catch (e) {
          print('HealthDataProvider - Error syncing medication ${medication.name}: $e');
        }
      }
      
      // Sync appointments
      print('HealthDataProvider - Syncing appointments...');
      for (final appointment in _appointments ?? []) {
        try {
          await _firestore!.addAppointment(appointment, uid);
        } catch (e) {
          print('HealthDataProvider - Error syncing appointment ${appointment.title}: $e');
        }
      }
      
      // Sync logs
      print('HealthDataProvider - Syncing logs...');
      for (final log in _logs ?? []) {
        try {
          await _firestore!.addLog(log, uid);
        } catch (e) {
          print('HealthDataProvider - Error syncing log: $e');
        }
      }
      
      // Sync health data
      print('HealthDataProvider - Syncing health data...');
      final healthData = {
        'waterIntake': _waterIntake,
        'bloodPressure': _bloodPressure,
        'bloodSugar': _bloodSugar,
        'peakFlow': _peakFlow,
        'painLevel': _painLevel,
        'streakData': {
          'completionStatus': _dailyMedicationCompletionStatus,
          'currentStreak': _currentStreak,
          'longestStreak': _longestStreak,
        },
      };
      await _firestore!.saveHealthData(uid, healthData);
      
      // Update sync status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toString());
      await prefs.setString('sync_status', 'success');
      
      print('HealthDataProvider - ✅ Manual sync to Firestore completed successfully');
      
    } catch (e) {
      print('HealthDataProvider - Error in manual sync to Firestore: $e');
      
      // Update sync status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_status', 'error');
      
      throw Exception('Failed to sync to cloud: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Method to manually restore data from Firestore
  Future<void> restoreDataFromFirestore(UserProfile userProfile) async {
    try {
      print('HealthDataProvider - Starting manual restore from Firestore...');
      _setLoading(true);
      _clearError();
      
      final uid = _auth?.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }
      
      if (_firestore == null) {
        throw Exception('Firestore service not available');
      }
      
      // Get medications from Firestore
      print('HealthDataProvider - Restoring medications...');
      final medicationsSnapshot = await _firestore!.getMedications(uid);
      _medications = medicationsSnapshot.map((m) => Medication.fromJson(m)).toList();
      
      // Get appointments from Firestore
      print('HealthDataProvider - Restoring appointments...');
      final appointmentsSnapshot = await _firestore!.getAppointments(uid);
      _appointments = appointmentsSnapshot.map((a) => Appointment.fromJson(a)).toList();
      
      // Get logs from Firestore
      print('HealthDataProvider - Restoring logs...');
      final logsSnapshot = await _firestore!.getLogs(uid);
      _logs = logsSnapshot.map((l) => LogEntry.fromJson(l)).toList();
      
      // Get health data from Firestore
      print('HealthDataProvider - Restoring health data...');
      final healthData = await _firestore!.getHealthData(uid);
      if (healthData != null) {
        _waterIntake = Map<String, int>.from(healthData['waterIntake'] ?? {});
        _bloodPressure = (healthData['bloodPressure'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, List<int>.from(v))) ?? {};
        _bloodSugar = Map<String, int>.from(healthData['bloodSugar'] ?? {});
        _peakFlow = Map<String, int>.from(healthData['peakFlow'] ?? {});
        _painLevel = Map<String, int>.from(healthData['painLevel'] ?? {});
        
        // Load streak data
        final streakData = healthData['streakData'] as Map<String, dynamic>?;
        if (streakData != null) {
          _dailyMedicationCompletionStatus = Map<String, bool>.from(streakData['completionStatus'] ?? {});
          _currentStreak = streakData['currentStreak'] ?? 0;
          _longestStreak = streakData['longestStreak'] ?? 0;
        }
      }
      
      // Save all restored data to SharedPreferences
      await saveAllDataToSharedPreferences();
      
      // Update sync status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', DateTime.now().toString());
      await prefs.setString('sync_status', 'success');
      
      print('HealthDataProvider - ✅ Manual restore from Firestore completed successfully');
      notifyListeners();
      
    } catch (e) {
      print('HealthDataProvider - Error in manual restore from Firestore: $e');
      
      // Update sync status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('sync_status', 'error');
      
      throw Exception('Failed to restore from cloud: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Method to force reload all data from SharedPreferences
  Future<void> forceReloadData() async {
    try {
      print('HealthDataProvider - Force reloading all data from SharedPreferences...');
      _setLoading(true);
      _clearError();
      
      await loadAllDataFromSharedPreferences();
      
      // Ensure we have at least empty lists
      _medications ??= [];
      _appointments ??= [];
      _logs ??= [];
      
      print('HealthDataProvider - ✅ Force reload completed');
      notifyListeners();
    } catch (e) {
      print('HealthDataProvider - Error in force reload: $e');
      _setError('Failed to reload data: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Method to test Firestore connectivity
  Future<void> testFirestoreConnection(UserProfile userProfile) async {
    try {
      print('HealthDataProvider - Testing Firestore connection...');
      
      if (_firestore == null) {
        throw Exception('Firestore service not available');
      }
      
      // Run comprehensive diagnosis
      final diagnosis = await _firestore!.diagnoseFirestoreIssues();
      print('HealthDataProvider - Firestore diagnosis results: $diagnosis');
      
      // Run operation tests
      final operations = await _firestore!.testFirestoreOperations();
      print('HealthDataProvider - Firestore operation tests: $operations');
      
      // Check if any tests failed
      final failedTests = <String>[];
      diagnosis.forEach((key, value) {
        if (value.toString().startsWith('FAIL')) {
          failedTests.add('$key: $value');
        }
      });
      
      operations.forEach((key, value) {
        if (value.toString().startsWith('FAIL')) {
          failedTests.add('$key: $value');
        }
      });
      
      if (failedTests.isNotEmpty) {
        throw Exception('Firestore tests failed: ${failedTests.join(', ')}');
      }
      
      print('HealthDataProvider - ✅ All Firestore tests passed');
      
    } catch (e) {
      print('HealthDataProvider - ❌ Firestore connection test failed: $e');
      throw Exception('Firestore connection failed: ${e.toString()}');
    }
  }

  // Method to clear all user data (called on sign out)
  Future<void> clearAllUserData() async {
    try {
      print('HealthDataProvider - Clearing all user data...');
      
      // Clear all in-memory data
      _medications = [];
      _logs = [];
      _appointments = [];
      _userProfile = null;
      _waterIntake.clear();
      _bloodPressure.clear();
      _bloodSugar.clear();
      _peakFlow.clear();
      _painLevel.clear();
      _dailyMedicationCompletionStatus.clear();
      _currentStreak = 0;
      _longestStreak = 0;
      
      // Clear error and loading states
      _errorMessage = null;
      _isLoading = false;
      
      // Cancel any active subscriptions
      await _profileSubscription?.cancel();
      await _medicationSubscription?.cancel();
      await _appointmentSubscription?.cancel();
      await _logSubscription?.cancel();
      await _healthDataSubscription?.cancel();
      
      _profileSubscription = null;
      _medicationSubscription = null;
      _appointmentSubscription = null;
      _logSubscription = null;
      _healthDataSubscription = null;
      
      // Clear services
      _auth = null;
      _firestore = null;
      
      print('HealthDataProvider - ✅ All user data cleared');
      notifyListeners();
    } catch (e) {
      print('HealthDataProvider - Error clearing user data: $e');
    }
  }
} 