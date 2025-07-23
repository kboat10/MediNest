import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/log_entry.dart';
import '../widgets/loading_widget.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../providers/user_preferences_provider.dart';

enum MedicationStatus {
  taken,
  missed,
  notLogged,
}

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _feelingController = TextEditingController();
  final TextEditingController _bpSysController = TextEditingController();
  final TextEditingController _bpDiaController = TextEditingController();
  final TextEditingController _sugarController = TextEditingController();
  final TextEditingController _peakFlowController = TextEditingController();
  static const List<String> _allSymptoms = [
    'Headache', 'Fever', 'Nausea', 'Fatigue', 'Cough', 'Sore throat', 'Shortness of breath', 'Muscle pain', 'No symptoms',
  ];
  final List<String> _selectedSymptoms = [];

  @override
  void dispose() {
    _searchController.dispose();
    _feelingController.dispose();
    _bpSysController.dispose();
    _bpDiaController.dispose();
    _sugarController.dispose();
    _peakFlowController.dispose();
    super.dispose();
  }

  // 1. Refactor `setMedicationTakenStatus` to use Firestore methods
  Future<void> setMedicationTakenStatus(HealthDataProvider provider, Medication med, DateTime date, bool taken) async {
    print('DEBUG: setMedicationTakenStatus called for ${med.name}, taken: $taken, date: ${date.toIso8601String()}');
    
    // If marking as taken, show confirmation dialog
    if (taken) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirm Medication Taken'),
            content: Text('Are you sure you want to mark "${med.name}" as taken? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Taken'),
              ),
            ],
          );
        },
      );
      
      if (confirmed != true) {
        print('DEBUG: User cancelled the confirmation dialog');
        return; // User cancelled
      }
    }
    
    print('DEBUG: Looking for existing log for ${med.name} on ${date.toIso8601String()}');
    // Find and delete any existing log for this med/date
    final existingLog = provider.logs.firstWhere(
      (l) => l.type == 'medication' &&
             l.date.year == date.year &&
             l.date.month == date.month &&
             l.date.day == date.day &&
             (l.description == 'Took ${med.name}' || l.description == 'Missed ${med.name}'),
      orElse: () => LogEntry(id: null, date: DateTime.now(), description: '', type: ''), // Dummy
    );
    
    if (existingLog.id != null) {
      print('DEBUG: Found existing log, deleting it: ${existingLog.description}');
      await provider.deleteLog(existingLog.id!);
    } else {
      print('DEBUG: No existing log found');
    }
    
    // Add a new log
    final logDescription = taken ? 'Took ${med.name}' : 'Missed ${med.name}';
    print('DEBUG: Creating new log with description: $logDescription');
    print('DEBUG: Log date being used: ${date.toIso8601String()}');
    print('DEBUG: Current selected date: ${_selectedDate.toIso8601String()}');
    
    final newLog = await provider.addLog(LogEntry(
      date: date,
      description: logDescription,
      type: 'medication',
    ));
    
    print('DEBUG: New log created with ID: ${newLog.id}');
    print('DEBUG: New log date: ${newLog.date.toIso8601String()}');
    
    // Update medication streak tracking
    await provider.updateMedicationStreak(date);
    
    // Force provider to reload data from SharedPreferences to ensure UI gets latest data
    await provider.loadAllDataFromSharedPreferences();
    
    // Add a small delay to ensure all async operations complete
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Debug: Check what logs are available after the update
    print('DEBUG: After update - Total logs: ${provider.logs.length}');
    for (final log in provider.logs) {
      print('DEBUG: Log: ${log.description} | Date: ${log.date.toIso8601String()} | Type: ${log.type}');
    }
    
    // Force provider to notify all listeners
    provider.notifyListeners();
    
    // Force UI refresh with multiple approaches
    if (mounted) {
      setState(() {});
      // Force rebuild of the entire widget tree
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(taken ? 'Marked ${med.name} as taken' : 'Marked ${med.name} as missed'),
          backgroundColor: taken ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // 2. Remove the old `getMedicationTakenStatus`, `_getLogTypeColor`, and `_showEditDialog` methods.
  // 3. Update the ListView.builder to directly check the log status.
  //    (This will be a larger change, including checkbox logic)

  // Helper method to determine medication status
  MedicationStatus _getMedicationStatus(HealthDataProvider healthData, Medication med, DateTime selectedDate) {
    // Check each log to find matching medication for the selected date
    for (final log in healthData.logs) {
      if (log.type == 'medication' &&
          log.date.year == selectedDate.year &&
          log.date.month == selectedDate.month &&
          log.date.day == selectedDate.day &&
          (log.description == 'Took ${med.name}' || log.description == 'Missed ${med.name}')) {
        // Found matching log - return status based on description
        return log.description.startsWith('Took') 
            ? MedicationStatus.taken 
            : MedicationStatus.missed;
      }
    }
    
    // No matching log found - user hasn't logged this medication yet
    return MedicationStatus.notLogged;
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

  // Helper method to get status display info
  Map<String, dynamic> _getStatusDisplayInfo(MedicationStatus status) {
    switch (status) {
      case MedicationStatus.taken:
        return {
          'text': 'Took',
          'color': Colors.green,
          'icon': Icons.check_circle,
          'checkboxValue': true,
        };
      case MedicationStatus.missed:
        return {
          'text': 'Missed',
          'color': Colors.red,
          'icon': Icons.cancel,
          'checkboxValue': false,
        };
      case MedicationStatus.notLogged:
        return {
          'text': 'Not logged',
          'color': Colors.grey,
          'icon': Icons.help_outline,
          'checkboxValue': null,
        };
    }
  }

  // Helper method to get log type icon
  IconData _getLogTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return Icons.medication;
      case 'daily':
        return Icons.sentiment_satisfied;
      case 'appointment':
        return Icons.calendar_today;
      case 'exercise':
        return Icons.fitness_center;
      case 'diet':
        return Icons.restaurant;
      case 'sleep':
        return Icons.bedtime;
      case 'mood':
        return Icons.psychology;
      default:
        return Icons.note;
    }
  }

  // Helper method to get log type color
  Color _getLogTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return Colors.blue;
      case 'daily':
        return Colors.green;
      case 'appointment':
        return Colors.orange;
      case 'exercise':
        return Colors.purple;
      case 'diet':
        return Colors.brown;
      case 'sleep':
        return Colors.indigo;
      case 'mood':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HealthDataProvider, UserPreferencesProvider>(
      builder: (context, healthData, userPrefs, child) {
        
        Widget body;
        if (healthData.medications == null) {
          body = const LoadingWidget(message: 'Loading your logs...');
        } else if (healthData.errorMessage != null && healthData.logs.isEmpty) {
          body = _buildErrorWidget(context, healthData.errorMessage!, healthData.clearError);
        } else if (healthData.logs.isEmpty && healthData.medications.isEmpty) {
          body = _buildEmptyState();
        } else {
          body = _buildLogContent(context, healthData, userPrefs);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Health Logs'),
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildLogContent(BuildContext context, HealthDataProvider healthData, UserPreferencesProvider userPrefs) {
    final condition = userPrefs.healthCondition.trim().toLowerCase();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Date picker
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text('Date:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 365)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Feeling and symptoms input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How are you feeling today?', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _feelingController,
                  decoration: const InputDecoration(
                    hintText: 'Describe your feeling (e.g. Good, Tired, Anxious)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Select symptoms:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _allSymptoms.map((symptom) {
                    final selected = _selectedSymptoms.contains(symptom);
                    return FilterChip(
                      label: Text(symptom),
                      selected: selected,
                      onSelected: (val) {
                        setState(() {
                          if (val) {
                            _selectedSymptoms.add(symptom);
                          } else {
                            _selectedSymptoms.remove(symptom);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_comment),
                  label: const Text('Add to Log'),
                  onPressed: () async {
                    print('DEBUG: Add to Log button pressed');
                    print('DEBUG: Feeling: "${_feelingController.text.trim()}"');
                    print('DEBUG: Symptoms: $_selectedSymptoms');
                    print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                    
                    if (_feelingController.text.trim().isEmpty && _selectedSymptoms.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a feeling or select at least one symptom.')),
                      );
                      return;
                    }
                    
                    try {
                      await healthData.addDailyFeelingLog(
                        _selectedDate,
                        _feelingController.text.trim(),
                        List<String>.from(_selectedSymptoms),
                      );
                      
                      print('DEBUG: Daily feeling log added successfully');
                      print('DEBUG: After adding log - Total logs: ${healthData.logs.length}');
                      print('DEBUG: After adding log - Daily logs: ${healthData.logs.where((l) => l.type == 'daily').length}');
                      
                      // Force provider to reload data to ensure UI gets latest data
                      await healthData.loadAllDataFromSharedPreferences();
                      print('DEBUG: After reload - Total logs: ${healthData.logs.length}');
                      print('DEBUG: After reload - Daily logs: ${healthData.logs.where((l) => l.type == 'daily').length}');
                      
                      setState(() {
                        _feelingController.clear();
                        _selectedSymptoms.clear();
                      });
                      
                      // Force UI refresh
                      if (mounted) {
                        setState(() {});
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Daily feeling and symptoms logged successfully!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      print('DEBUG: Error adding daily feeling log: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error logging feeling: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          // Water Intake Tracker
          if (condition == 'sickle cell disease') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text('Water Intake:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () async {
                      print('DEBUG: Decrement water intake button pressed');
                      print('DEBUG: Current water intake: ${healthData.getWaterIntake(_selectedDate)}');
                      print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                      
                      await healthData.decrementWaterIntake(_selectedDate);
                      print('DEBUG: Water intake decremented successfully');
                      setState(() {});
                    },
                  ),
                  Text(
                    '${healthData.getWaterIntake(_selectedDate)} glasses',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      print('DEBUG: Increment water intake button pressed');
                      print('DEBUG: Current water intake: ${healthData.getWaterIntake(_selectedDate)}');
                      print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                      
                      await healthData.incrementWaterIntake(_selectedDate);
                      print('DEBUG: Water intake incremented successfully');
                      setState(() {});
                    },
                  ),
                  if (healthData.getWaterIntake(_selectedDate) < 8)
                    const Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Icon(Icons.warning, color: Colors.orange),
                    ),
                ],
              ),
            ),
            if (healthData.getWaterIntake(_selectedDate) < 8)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Try to drink at least 8 glasses of water today to help prevent sickle cell crises.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
          ],
          // Medication checklist for the day
          if (healthData.medications.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: Center(
                child: Text('No medications scheduled. Add medications on the Schedule page.'),
              ),
            )
          else
            _buildMedicationChecklist(healthData, healthData.medications),
            
          // Blood Pressure Tracker
          if (condition == 'hypertension') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text('Blood Pressure:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Systolic', isDense: true),
                      controller: _bpSysController,
                    ),
                  ),
                  const Text('/', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Diastolic', isDense: true),
                      controller: _bpDiaController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      print('DEBUG: Blood pressure save button pressed');
                      print('DEBUG: Systolic: ${_bpSysController.text}');
                      print('DEBUG: Diastolic: ${_bpDiaController.text}');
                      print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                      
                      final sys = int.tryParse(_bpSysController.text);
                      final dia = int.tryParse(_bpDiaController.text);
                      
                      if (sys != null && dia != null) {
                        try {
                          await healthData.setBloodPressure(_selectedDate, sys, dia);
                          print('DEBUG: Blood pressure saved successfully');
                          print('DEBUG: After saving - Blood pressure for date: ${healthData.getBloodPressure(_selectedDate)}');
                          
                          setState(() {
                            _bpSysController.clear();
                            _bpDiaController.clear();
                          });
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Blood pressure saved: $sys/$dia mmHg'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          print('DEBUG: Error saving blood pressure: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving blood pressure: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter valid systolic and diastolic values'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            if (healthData.getBloodPressure(_selectedDate) != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text('Latest: ${healthData.getBloodPressure(_selectedDate)![0]}/${healthData.getBloodPressure(_selectedDate)![1]} mmHg'),
                    if (healthData.getBloodPressure(_selectedDate)![0] > 140 || healthData.getBloodPressure(_selectedDate)![1] > 90)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.warning, color: Colors.orange),
                      ),
                    if (healthData.getBloodPressure(_selectedDate)![0] < 90 || healthData.getBloodPressure(_selectedDate)![1] < 60)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.warning, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            if (healthData.getBloodPressure(_selectedDate) != null &&
                (healthData.getBloodPressure(_selectedDate)![0] > 140 || healthData.getBloodPressure(_selectedDate)![1] > 90))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your blood pressure is high. Please consult your doctor and follow your medication plan.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
            if (healthData.getBloodPressure(_selectedDate) != null &&
                (healthData.getBloodPressure(_selectedDate)![0] < 90 || healthData.getBloodPressure(_selectedDate)![1] < 60))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your blood pressure is low. Please rest and consult your doctor if you feel unwell.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
          ],
          // Blood Sugar Tracker
          if (condition == 'diabetes') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text('Blood Sugar:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'mg/dL', isDense: true),
                      controller: _sugarController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      print('DEBUG: Blood sugar save button pressed');
                      print('DEBUG: Blood sugar: ${_sugarController.text}');
                      print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                      
                      final sugar = int.tryParse(_sugarController.text);
                      if (sugar != null) {
                        try {
                          await healthData.setBloodSugar(_selectedDate, sugar);
                          print('DEBUG: Blood sugar saved successfully');
                          print('DEBUG: After saving - Blood sugar for date: ${healthData.getBloodSugar(_selectedDate)}');
                          setState(() {});
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Blood sugar saved: $sugar mg/dL'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          print('DEBUG: Error saving blood sugar: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving blood sugar: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid blood sugar value'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            if (healthData.getBloodSugar(_selectedDate) != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text('Latest: ${healthData.getBloodSugar(_selectedDate)} mg/dL'),
                    if (healthData.getBloodSugar(_selectedDate)! > 180)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.warning, color: Colors.orange),
                      ),
                    if (healthData.getBloodSugar(_selectedDate)! < 70)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.warning, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            if (healthData.getBloodSugar(_selectedDate) != null && healthData.getBloodSugar(_selectedDate)! > 180)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your blood sugar is high. Please follow your diabetes plan and consult your doctor.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
            if (healthData.getBloodSugar(_selectedDate) != null && healthData.getBloodSugar(_selectedDate)! < 70)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your blood sugar is low. Please eat or drink something sugary and consult your doctor if needed.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
          ],
          // Peak Flow Tracker
          if (condition == 'asthma') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Text('Peak Flow:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'L/min', isDense: true),
                      controller: _peakFlowController,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      print('DEBUG: Peak flow save button pressed');
                      print('DEBUG: Peak flow: ${_peakFlowController.text}');
                      print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                      
                      final pf = int.tryParse(_peakFlowController.text);
                      if (pf != null) {
                        try {
                          await healthData.setPeakFlow(_selectedDate, pf);
                          print('DEBUG: Peak flow saved successfully');
                          print('DEBUG: After saving - Peak flow for date: ${healthData.getPeakFlow(_selectedDate)}');
                          setState(() {});
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Peak flow saved: $pf L/min'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          print('DEBUG: Error saving peak flow: $e');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error saving peak flow: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid peak flow value'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                    child: const Text('Save'),
                  ),
                ],
              ),
            ),
            if (healthData.getPeakFlow(_selectedDate) != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Text('Latest: ${healthData.getPeakFlow(_selectedDate)} L/min'),
                    if (healthData.getPeakFlow(_selectedDate)! < 300)
                      const Padding(
                        padding: EdgeInsets.only(left: 12),
                        child: Icon(Icons.warning, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            if (healthData.getPeakFlow(_selectedDate) != null && healthData.getPeakFlow(_selectedDate)! < 300)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Your peak flow is low. Use your inhaler as prescribed and consult your doctor if symptoms persist.',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
                ),
              ),
          ],
          // Pain Level Tracker (for sickle cell and general pain tracking)
          if (condition == 'sickle cell disease' || condition == 'chronic pain') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Pain Level (1-10):', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: (healthData.getPainLevel(_selectedDate) ?? 0).toDouble(),
                          min: 0,
                          max: 10,
                          divisions: 10,
                          label: '${healthData.getPainLevel(_selectedDate) ?? 0}',
                          onChanged: (value) async {
                            print('DEBUG: Pain level slider changed to: ${value.toInt()}');
                            print('DEBUG: Selected date: ${_selectedDate.toIso8601String()}');
                            
                            await healthData.setPainLevel(_selectedDate, value.toInt());
                            print('DEBUG: Pain level saved successfully');
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${healthData.getPainLevel(_selectedDate) ?? 0}/10',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  if (healthData.getPainLevel(_selectedDate) != null && healthData.getPainLevel(_selectedDate)! >= 7)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text(
                        'High pain level detected. Please consult your doctor and consider taking prescribed pain medication.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // Summary
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary for the day:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                
                // Debug: Print current data for troubleshooting
                Builder(
                  builder: (context) {
                    print('DEBUG: Summary section - Selected date: ${_selectedDate.toIso8601String()}');
                    print('DEBUG: Summary section - Total logs: ${healthData.logs.length}');
                    print('DEBUG: Summary section - Daily logs: ${healthData.logs.where((l) => l.type == 'daily').length}');
                    print('DEBUG: Summary section - Water intake: ${healthData.getWaterIntake(_selectedDate)}');
                    print('DEBUG: Summary section - Blood pressure: ${healthData.getBloodPressure(_selectedDate)}');
                    print('DEBUG: Summary section - Blood sugar: ${healthData.getBloodSugar(_selectedDate)}');
                    print('DEBUG: Summary section - Peak flow: ${healthData.getPeakFlow(_selectedDate)}');
                    print('DEBUG: Summary section - Pain level: ${healthData.getPainLevel(_selectedDate)}');
                    
                    final dailyLogs = healthData.logs.where((l) => 
                      l.type == 'daily' && 
                      l.date.year == _selectedDate.year && 
                      l.date.month == _selectedDate.month && 
                      l.date.day == _selectedDate.day
                    ).toList();
                    
                    print('DEBUG: Summary section - Daily logs for selected date: ${dailyLogs.length}');
                    for (final log in dailyLogs) {
                      print('DEBUG: Summary section - Daily log: feeling=${log.feeling}, symptoms=${log.symptoms}');
                    }
                    
                    return const SizedBox.shrink();
                  },
                ),
                
                // Medication Status Summary
                if (healthData.medications.isNotEmpty) ...[
                  const Text('Medications:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  ...healthData.medications.map((med) {
                    final status = _getMedicationStatus(healthData, med, _selectedDate);
                    final displayInfo = _getStatusDisplayInfo(status);
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Icon(
                            displayInfo['icon'],
                            size: 16,
                            color: displayInfo['color'],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${med.name}: ',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (displayInfo['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              displayInfo['text'],
                              style: TextStyle(
                                color: displayInfo['color'],
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                
                // Daily Feelings and Symptoms
                Builder(
                  builder: (context) {
                    final dailyLogs = healthData.logs.where((l) => 
                      l.type == 'daily' && 
                      l.date.year == _selectedDate.year && 
                      l.date.month == _selectedDate.month && 
                      l.date.day == _selectedDate.day
                    ).toList();
                    
                    if (dailyLogs.isNotEmpty) {
                      final log = dailyLogs.last;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Daily Health Log:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 8),
                          if (log.feeling != null && log.feeling!.isNotEmpty) ...[
                            Row(
                              children: [
                                const Icon(Icons.sentiment_satisfied, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Feeling: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text(log.feeling!),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (log.symptoms != null && log.symptoms!.isNotEmpty) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.medical_services, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Symptoms: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Expanded(
                                  child: Text(log.symptoms!.join(', ')),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
                
                // Condition-Specific Vitals Summary
                Builder(
                  builder: (context) {
                    final hasVitals = healthData.getWaterIntake(_selectedDate) > 0 ||
                                    healthData.getBloodPressure(_selectedDate) != null ||
                                    healthData.getBloodSugar(_selectedDate) != null ||
                                    healthData.getPeakFlow(_selectedDate) != null ||
                                    healthData.getPainLevel(_selectedDate) != null;
                    
                    if (hasVitals) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vital Signs:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 8),
                          
                          // Water Intake (for all users, especially important for sickle cell)
                          if (healthData.getWaterIntake(_selectedDate) > 0) ...[
                            Row(
                              children: [
                                const Icon(Icons.water_drop, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Text('Water Intake: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${healthData.getWaterIntake(_selectedDate)} glasses'),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          
                          // Blood Pressure (for hypertension and general health)
                          if (healthData.getBloodPressure(_selectedDate) != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.favorite, size: 16, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Blood Pressure: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${healthData.getBloodPressure(_selectedDate)![0]}/${healthData.getBloodPressure(_selectedDate)![1]} mmHg'),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          
                          // Blood Sugar (for diabetes)
                          if (healthData.getBloodSugar(_selectedDate) != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.monitor_heart, size: 16, color: Colors.orange),
                                const SizedBox(width: 8),
                                const Text('Blood Sugar: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${healthData.getBloodSugar(_selectedDate)} mg/dL'),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          
                          // Peak Flow (for asthma)
                          if (healthData.getPeakFlow(_selectedDate) != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.air, size: 16, color: Colors.green),
                                const SizedBox(width: 8),
                                const Text('Peak Flow: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${healthData.getPeakFlow(_selectedDate)} L/min'),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          
                          // Pain Level (for sickle cell and general pain tracking)
                          if (healthData.getPainLevel(_selectedDate) != null) ...[
                            Row(
                              children: [
                                const Icon(Icons.sick, size: 16, color: Colors.purple),
                                const SizedBox(width: 8),
                                const Text('Pain Level: ', style: TextStyle(fontWeight: FontWeight.w500)),
                                Text('${healthData.getPainLevel(_selectedDate)}/10'),
                              ],
                            ),
                            const SizedBox(height: 4),
                          ],
                          
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
                
                // Other Activities Summary
                Builder(
                  builder: (context) {
                    final otherLogs = healthData.logs.where((l) => 
                      l.type != 'medication' && 
                      l.type != 'daily' && 
                      l.date.year == _selectedDate.year && 
                      l.date.month == _selectedDate.month && 
                      l.date.day == _selectedDate.day
                    ).toList();
                    
                    if (otherLogs.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Other Activities:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          const SizedBox(height: 8),
                          ...otherLogs.map((log) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(
                                  _getLogTypeIcon(log.type),
                                  size: 16,
                                  color: _getLogTypeColor(log.type),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    log.description,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          )),
                          const SizedBox(height: 16),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
                
                // No Data Message
                Builder(
                  builder: (context) {
                    final hasMedications = healthData.medications.isNotEmpty;
                    final hasDailyLogs = healthData.logs.any((l) => 
                      l.type == 'daily' && 
                      l.date.year == _selectedDate.year && 
                      l.date.month == _selectedDate.month && 
                      l.date.day == _selectedDate.day
                    );
                    final hasVitals = healthData.getWaterIntake(_selectedDate) > 0 ||
                                    healthData.getBloodPressure(_selectedDate) != null ||
                                    healthData.getBloodSugar(_selectedDate) != null ||
                                    healthData.getPeakFlow(_selectedDate) != null ||
                                    healthData.getPainLevel(_selectedDate) != null;
                    final hasOtherLogs = healthData.logs.any((l) => 
                      l.type != 'medication' && 
                      l.type != 'daily' && 
                      l.date.year == _selectedDate.year && 
                      l.date.month == _selectedDate.month && 
                      l.date.day == _selectedDate.day
                    );
                    
                    if (!hasMedications && !hasDailyLogs && !hasVitals && !hasOtherLogs) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'No health data logged for this date. Use the forms above to add your daily health information.',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
          if (!['sickle cell disease', 'hypertension', 'diabetes', 'asthma'].contains(condition))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'No condition-specific tracker available. Please set your health condition in settings.',
                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicationChecklist(HealthDataProvider healthData, List<Medication> medications) {
    return Consumer<HealthDataProvider>(
      builder: (context, provider, child) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: medications.length,
          itemBuilder: (context, idx) {
            final med = medications[idx];
            final status = _getMedicationStatus(provider, med, _selectedDate);
            final displayInfo = _getStatusDisplayInfo(status);
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Medication header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (displayInfo['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            displayInfo['icon'],
                            color: displayInfo['color'],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                med.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Time: ${med.time}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              ),
                              if (med.reminderTime != null && med.reminderTime != med.time)
                                Text(
                                  'Reminder: ${med.reminderTime}', 
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Always show checkboxes for user control (no time-based logic)
                    Row(
                      children: [
                        // Taken checkbox
                        Expanded(
                          child: InkWell(
                            onTap: status == MedicationStatus.taken 
                              ? null // Disable tap if already taken
                              : () async {
                                  await setMedicationTakenStatus(provider, med, _selectedDate, true);
                                },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: status == MedicationStatus.taken 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: status == MedicationStatus.taken 
                                    ? Colors.green 
                                    : Colors.grey.withOpacity(0.3),
                                  width: status == MedicationStatus.taken ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: status == MedicationStatus.taken,
                                      onChanged: status == MedicationStatus.taken 
                                        ? null // Disable checkbox if already taken
                                        : (val) async {
                                            if (val == true) {
                                              await setMedicationTakenStatus(provider, med, _selectedDate, true);
                                            }
                                          },
                                      activeColor: Colors.green,
                                      checkColor: Colors.white,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.check_circle,
                                    color: status == MedicationStatus.taken ? Colors.green : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Taken',
                                      style: TextStyle(
                                        color: status == MedicationStatus.taken ? Colors.green : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (status == MedicationStatus.taken) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.lock,
                                      color: Colors.green,
                                      size: 12,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        // Missed checkbox
                        Expanded(
                          child: InkWell(
                            onTap: status == MedicationStatus.taken 
                              ? null // Disable if already taken
                              : () async {
                                  await setMedicationTakenStatus(provider, med, _selectedDate, false);
                                },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: status == MedicationStatus.missed 
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: status == MedicationStatus.missed 
                                    ? Colors.red 
                                    : Colors.grey.withOpacity(0.3),
                                  width: status == MedicationStatus.missed ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: Checkbox(
                                      value: status == MedicationStatus.missed,
                                      onChanged: status == MedicationStatus.taken 
                                        ? null // Disable if already taken
                                        : (val) async {
                                            if (val == true) {
                                              await setMedicationTakenStatus(provider, med, _selectedDate, false);
                                            }
                                          },
                                      activeColor: Colors.red,
                                      checkColor: Colors.white,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.cancel,
                                    color: status == MedicationStatus.missed ? Colors.red : Colors.grey,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Missed',
                                      style: TextStyle(
                                        color: status == MedicationStatus.missed ? Colors.red : Colors.grey,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Logs Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Use the form above to log your daily feelings, symptoms, and condition-specific metrics.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context, String message, VoidCallback onClear) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 16),
          Text('Something Went Wrong', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onClear,
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }


} 