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
  Future<void> incrementWaterIntake(DateTime date) async {
    final key = '${date.year}-${date.month}-${date.day}';
    _waterIntake[key] = (_waterIntake[key] ?? 0) + 1;
    await _saveWaterIntakeData();
    await _saveHealthDataToFirestore();
    notifyListeners();
  }
  Future<void> decrementWaterIntake(DateTime date) async {
    final key = '${date.year}-${date.month}-${date.day}';
    if ((_waterIntake[key] ?? 0) > 0) {
      _waterIntake[key] = _waterIntake[key]! - 1;
      await _saveWaterIntakeData();
      await _saveHealthDataToFirestore();
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
    await _saveHealthDataToFirestore();
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
    await _saveHealthDataToFirestore();
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
    await _saveHealthDataToFirestore();
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

  // Data persistence methods
  Future<void> _loadData() async {
    try {
      _setLoading(true);
      _clearError();
      
      final prefs = await SharedPreferences.getInstance();
      
      // Load medications
      final medicationsJson = prefs.getStringList(_medicationsKey) ?? [];
      _medications = medicationsJson
          .map((json) => Medication.fromJson(jsonDecode(json)))
          .toList();
      
      // Load logs
      final logsJson = prefs.getStringList(_logsKey) ?? [];
      _logs = logsJson
          .map((json) => LogEntry.fromJson(jsonDecode(json)))
          .toList();
      
      // Load appointments
      final appointmentsJson = prefs.getStringList(_appointmentsKey) ?? [];
      _appointments = appointmentsJson
          .map((json) => Appointment.fromJson(jsonDecode(json)))
          .toList();
      
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
      final medicationsJson = (_medications ?? [])
          .map((med) => jsonEncode(med.toJson()))
          .toList();
      await prefs.setStringList(_medicationsKey, medicationsJson);
      
      // Save logs
      final logsJson = (_logs ?? [])
          .map((log) => jsonEncode(log.toJson(forFirestore: false)))
          .toList();
      await prefs.setStringList(_logsKey, logsJson);
      
      // Save appointments
      final appointmentsJson = (_appointments ?? [])
          .map((appt) => jsonEncode(appt.toJson(forFirestore: false)))
          .toList();
      await prefs.setStringList(_appointmentsKey, appointmentsJson);

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

  // Called by ChangeNotifierProxyProvider when dependencies change
  void update(AuthService auth, FirestoreService firestore) {
    _auth = auth;
    _firestore = firestore;

    // Cancel any existing subscription to avoid memory leaks
    _medicationSubscription?.cancel();
    _appointmentSubscription?.cancel();
    _logSubscription?.cancel();
    _profileSubscription?.cancel();
    _healthDataSubscription?.cancel();

    if (auth.currentUser != null) {
      // Set lists to null to indicate loading state
      _medications = null;
      _appointments = null;
      _logs = null;
      _userProfile = null;
      notifyListeners();

      // If user is logged in, listen to Firestore
      _medicationSubscription = _firestore?.medicationsStream(auth.currentUser!.uid).listen((meds) {
        _medications = meds.map((m) => Medication.fromJson(m)).toList();
        // Update streaks whenever medications change
        _updateMedicationStreaks();
        notifyListeners();
      }, onError: (e) {
        _setError('Failed to load medications: $e');
        _medications = []; // Set to empty list on error
        notifyListeners();
      });
      _appointmentSubscription = _firestore?.appointmentsStream(auth.currentUser!.uid).listen((appointments) {
        _appointments = appointments.map((a) => Appointment.fromJson(a)).toList();
        notifyListeners();
      }, onError: (e) {
        _setError('Failed to load appointments: $e');
        _appointments = []; // Set to empty list on error
        notifyListeners();
      });
      _logSubscription = _firestore?.logsStream(auth.currentUser!.uid).listen((logs) {
        _logs = logs.map((l) => LogEntry.fromJson(l)).toList();
        // Update streaks whenever logs change
        _updateMedicationStreaks();
        notifyListeners();
      }, onError: (e) {
        _setError('Failed to load logs: $e');
        _logs = []; // Set to empty list on error
        notifyListeners();
      });
      _profileSubscription = _firestore?.userProfileStream(auth.currentUser!.uid).listen((profile) {
        _userProfile = profile;
        
        // If profile doesn't exist, create a default one
        if (profile == null && auth.currentUser != null) {
          _createDefaultProfile(auth.currentUser!);
        }
        
        notifyListeners();
      }, onError: (e) {
        _setError('Failed to load profile: $e');
        _userProfile = null; // Can remain null on error
        notifyListeners();
      });
      
      // Listen to health data changes
      _healthDataSubscription = _firestore?.healthDataStream(auth.currentUser!.uid).listen((healthData) {
        if (healthData != null) {
          // Load water intake
          if (healthData['waterIntake'] != null) {
            _waterIntake = Map<String, int>.from(healthData['waterIntake']);
          }
          
          // Load blood pressure
          if (healthData['bloodPressure'] != null) {
            _bloodPressure = (healthData['bloodPressure'] as Map<String, dynamic>)
                .map((k, v) => MapEntry(k, List<int>.from(v)));
          }
          
          // Load blood sugar
          if (healthData['bloodSugar'] != null) {
            _bloodSugar = Map<String, int>.from(healthData['bloodSugar']);
          }
          
          // Load peak flow
          if (healthData['peakFlow'] != null) {
            _peakFlow = Map<String, int>.from(healthData['peakFlow']);
          }
          
          // Load streak data
          if (healthData['streakData'] != null) {
            final streakData = healthData['streakData'];
            _dailyMedicationCompletionStatus = Map<String, bool>.from(streakData['completionStatus'] ?? {});
            _currentStreak = streakData['currentStreak'] ?? 0;
            _longestStreak = streakData['longestStreak'] ?? 0;
          }
          
          notifyListeners();
        }
      }, onError: (e) {
        _setError('Failed to load health data: $e');
      });
    } else {
      // If user is logged out, clear all data
      _medications = [];
      _appointments = [];
      _logs = [];
      _userProfile = null;
      notifyListeners();
    }
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
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      final docRef = await _firestore?.addMedication(medication, uid);
      return medication.copyWith(id: docRef?.id);
    }
    return medication; // Or throw an error
  }

  Future<void> updateMedication(String docId, Medication medication) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      await _firestore?.updateMedication(docId, medication); // Corrected arguments
    }
  }

  Future<void> deleteMedication(String docId) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      await _firestore?.deleteMedication(docId); // Corrected arguments
    }
  }

  Future<Appointment> addAppointment(Appointment appointment) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      final docRef = await _firestore!.addAppointment(appointment, uid);
      return Appointment(
        id: docRef.id,
        title: appointment.title,
        dateTime: appointment.dateTime,
        location: appointment.location,
        notes: appointment.notes,
      );
    }
    throw Exception('User not logged in');
  }

  Future<void> editAppointment(String docId, Appointment appointment) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      await _firestore?.updateAppointment(docId, appointment, uid);
    }
  }

  Future<void> deleteAppointment(String docId) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      await _firestore?.deleteAppointment(docId, uid);
    }
  }

  Future<LogEntry> addLog(LogEntry log) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      final docRef = await _firestore!.addLog(log, uid);
      return LogEntry(
        id: docRef.id,
        date: log.date,
        description: log.description,
        type: log.type,
        feeling: log.feeling,
        symptoms: log.symptoms,
      );
    }
    throw Exception('User not logged in');
  }

  Future<void> editLog(String docId, LogEntry log) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      await _firestore?.updateLog(docId, log, uid);
    }
  }

  Future<void> deleteLog(String docId) async {
    final uid = _auth?.currentUser?.uid;
    if (uid != null) {
      await _firestore?.deleteLog(docId, uid);
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
      await Future.delayed(const Duration(milliseconds: 500));
      _logs!.add(LogEntry(
        date: date,
        description: 'Daily feeling and symptoms',
        type: 'daily',
        feeling: feeling,
        symptoms: symptoms,
      ));
      await _saveData();
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
    await _firestore?.setUserProfile(profile);
  }

  // Create a default profile for users who don't have one
  Future<void> _createDefaultProfile(User user) async {
    try {
      // Try to get the name from onboarding data
      final prefs = await SharedPreferences.getInstance();
      final onboardingName = prefs.getString('user_name') ?? '';
      
      final defaultProfile = UserProfile(
        uid: user.uid,
        name: onboardingName.isNotEmpty ? onboardingName : (user.displayName ?? ''),
        email: user.email ?? '',
      );
      await _firestore?.setUserProfile(defaultProfile);
    } catch (e) {
      _setError('Failed to create profile: $e');
    }
  }
} 