import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/medication.dart';
import '../models/log_entry.dart';
import '../models/appointment.dart';

class HealthDataProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  
  List<Medication> _medications = [];
  List<LogEntry> _logs = [];
  List<Appointment> _appointments = [];

  // SharedPreferences keys
  static const String _medicationsKey = 'medications';
  static const String _logsKey = 'logs';
  static const String _appointmentsKey = 'appointments';

  HealthDataProvider() {
    _loadData();
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Medication> get medications => _medications;
  List<LogEntry> get logs => _logs;
  List<Appointment> get appointments => _appointments;

  Medication? get nextMedication {
    if (_medications.isEmpty) return null;
    return _medications.firstWhere((m) => !m.taken, orElse: () => _medications.first);
  }
  int get missedDoses => _logs.where((l) => l.type == 'medication' && l.description.startsWith('Missed')).length;
  int get weeklyAppointments => _appointments.where((a) => a.dateTime.isAfter(DateTime.now()) && a.dateTime.isBefore(DateTime.now().add(Duration(days: 7)))).length;

  // Returns the number of consecutive days (ending today or yesterday) where all scheduled medications were taken
  int get medicationStreak {
    if (_medications.isEmpty) return 0;
    // Build a map of date -> set of taken medication names
    final Map<DateTime, Set<String>> takenPerDay = {};
    for (final log in _logs) {
      if (log.type == 'medication' && log.description.startsWith('Took ')) {
        final medName = log.description.substring(5);
        final date = DateTime(log.date.year, log.date.month, log.date.day);
        takenPerDay.putIfAbsent(date, () => {}).add(medName);
      }
    }
    // Find the streak
    int streak = 0;
    DateTime day = DateTime.now();
    final allMedNames = _medications.map((m) => m.name).toSet();
    while (true) {
      final taken = takenPerDay[DateTime(day.year, day.month, day.day)] ?? {};
      if (taken.length == allMedNames.length) {
        streak++;
        day = day.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
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
      final medicationsJson = _medications
          .map((med) => jsonEncode(med.toJson()))
          .toList();
      await prefs.setStringList(_medicationsKey, medicationsJson);
      
      // Save logs
      final logsJson = _logs
          .map((log) => jsonEncode(log.toJson()))
          .toList();
      await prefs.setStringList(_logsKey, logsJson);
      
      // Save appointments
      final appointmentsJson = _appointments
          .map((appt) => jsonEncode(appt.toJson()))
          .toList();
      await prefs.setStringList(_appointmentsKey, appointmentsJson);
    } catch (e) {
      _setError('Failed to save data: ${e.toString()}');
    }
  }

  // Export/Import functionality
  Future<String> exportData() async {
    try {
      final exportData = {
        'medications': _medications.map((m) => m.toJson()).toList(),
        'logs': _logs.map((l) => l.toJson()).toList(),
        'appointments': _appointments.map((a) => a.toJson()).toList(),
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
      
      // Save imported data
      await _saveData();
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
      
      _medications[index] = _medications[index].copyWith(taken: true);
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
      
      _medications[index] = _medications[index].copyWith(taken: false);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to mark medication as missed: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addMedication(Medication medication) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _medications.add(medication);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add medication: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addLog(LogEntry log) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _logs.add(log);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add log entry: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addAppointment(Appointment appointment) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _appointments.add(appointment);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to add appointment: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Search and filter functionality
  List<Medication> searchMedications(String query) {
    if (query.isEmpty) return _medications;
    return _medications.where((med) => 
      med.name.toLowerCase().contains(query.toLowerCase()) ||
      med.time.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<LogEntry> searchLogs(String query) {
    if (query.isEmpty) return _logs;
    return _logs.where((log) => 
      log.description.toLowerCase().contains(query.toLowerCase()) ||
      log.type.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  List<Appointment> searchAppointments(String query) {
    if (query.isEmpty) return _appointments;
    return _appointments.where((appt) => 
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
      _medications[index] = _medications[index].copyWith(
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

  Future<void> editLog(int index, String description, String type) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _logs[index] = LogEntry(
        date: _logs[index].date,
        description: description,
        type: type,
      );
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to edit log entry: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> editAppointment(int index, String title, DateTime dateTime, String location, String notes) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _appointments[index] = Appointment(
        title: title,
        dateTime: dateTime,
        location: location,
        notes: notes,
      );
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to edit appointment: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  // Delete functionality
  Future<void> deleteMedication(int index) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _medications.removeAt(index);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete medication: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteLog(int index) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _logs.removeAt(index);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete log entry: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteAppointment(int index) async {
    try {
      _setLoading(true);
      _clearError();
      
      // Simulate async operation
      await Future.delayed(const Duration(milliseconds: 500));
      
      _appointments.removeAt(index);
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to delete appointment: ${e.toString()}');
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
      _medications.clear();
      _logs.clear();
      _appointments.clear();
      await _saveData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear data: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }
} 