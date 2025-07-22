import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../providers/health_data_provider.dart';
import '../providers/user_preferences_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../services/shared_prefs_service.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/log_entry.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({Key? key}) : super(key: key);

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isImporting = false;
  bool _isCreatingBackup = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Management'),
        elevation: 0,
      ),
      body: Consumer2<HealthDataProvider, UserPreferencesProvider>(
        builder: (context, healthData, preferences, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Data Overview
                _buildSectionHeader(context, 'Data Overview'),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildDataRow('Medications', '${healthData.medications.length} items'),
                        const Divider(),
                        _buildDataRow('Health Logs', '${healthData.logs.length} entries'),
                        const Divider(),
                        _buildDataRow('Appointments', '${healthData.appointments.length} scheduled'),
                      ],
                    ),
                  ),
                ),

                // Export/Import Section
                _buildSectionHeader(context, 'Export & Import'),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.picture_as_pdf,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Export Health Logs as PDF'),
                        subtitle: const Text('Generate and share a PDF of your health logs'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _exportHealthLogsAsPdf,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.download,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Import Data'),
                        subtitle: const Text('Load data from a file'),
                        trailing: _isImporting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isImporting ? null : _importData,
                      ),
                    ],
                  ),
                ),

                // Backup Section
                _buildSectionHeader(context, 'Backup & Restore'),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.backup,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Create Backup'),
                        subtitle: const Text('Save a backup of your data'),
                        trailing: _isCreatingBackup
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isCreatingBackup ? null : _createBackup,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.restore,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Restore from Backup'),
                        subtitle: const Text('Load data from a backup'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showBackupList,
                      ),
                    ],
                  ),
                ),

                // Data Actions Section
                _buildSectionHeader(context, 'Data Actions'),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.refresh,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Refresh Data'),
                        subtitle: const Text('Reload data from storage'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await healthData.loadData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Data refreshed successfully')),
                            );
                          }
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        title: const Text('Clear All Data'),
                        subtitle: const Text('Delete all data (irreversible)'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showClearDataDialog,
                      ),
                    ],
                  ),
                ),

                // Error Display
                if (healthData.errorMessage != null)
                  Card(
                    color: Colors.red[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error, color: Colors.red[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Error',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            healthData.errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => healthData.clearError(),
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _importData() async {
    setState(() {
      _isImporting = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        final file = result.files.first;
        final bytes = file.bytes;
        
        if (bytes != null) {
          final jsonString = String.fromCharCodes(bytes);
          final importData = jsonDecode(jsonString);
          
          final healthData = Provider.of<HealthDataProvider>(context, listen: false);
          final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
          
          // Import health data
          if (importData['healthData'] != null) {
            await healthData.importData(jsonEncode(importData['healthData']));
          }
          
          // Import preferences
          if (importData['preferences'] != null) {
            final prefs = importData['preferences'];
            await preferences.setDarkMode(prefs['darkMode'] ?? false);
            await preferences.setNotificationsEnabled(prefs['notificationsEnabled'] ?? true);
            await preferences.setMedicationReminders(prefs['medicationReminders'] ?? true);
            await preferences.setAppointmentReminders(prefs['appointmentReminders'] ?? true);
            await preferences.setPrimaryColor(Color(prefs['primaryColor'] ?? 0xFF2196F3));
            await preferences.setAccentColor(Color(prefs['accentColor'] ?? 0xFF2196F3));
            await preferences.setFontSize(prefs['fontSize'] ?? 1.0);
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Data imported successfully')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isImporting = false;
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isCreatingBackup = true;
    });

    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      await healthData.createBackup();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isCreatingBackup = false;
      });
    }
  }

  Future<void> _showBackupList() async {
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);
    final backups = await healthData.getBackups();
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Available Backups'),
        content: SizedBox(
          width: double.maxFinite,
          child: backups.isEmpty
              ? const Center(
                  child: Text('No backups available'),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  itemBuilder: (context, index) {
                    final backup = backups[index];
                    return ListTile(
                      title: Text(
                        'Backup ${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Date: ${_formatDate(backup['date'])}'),
                          Text(
                            'Medications: ${backup['medicationCount']}, '
                            'Logs: ${backup['logCount']}, '
                            'Appointments: ${backup['appointmentCount']}',
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'restore') {
                            Navigator.pop(context);
                            await _restoreBackup(backup['key']);
                          } else if (value == 'delete') {
                            Navigator.pop(context);
                            await _deleteBackup(backup['key']);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(Icons.restore),
                                SizedBox(width: 8),
                                Text('Restore'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(String backupKey) async {
    setState(() {
      _isCreatingBackup = true; // Changed from _isRestoring to _isCreatingBackup
    });

    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      await healthData.restoreBackup(backupKey);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isCreatingBackup = false; // Changed from _isRestoring to _isCreatingBackup
      });
    }
  }

  Future<void> _deleteBackup(String backupKey) async {
    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      await healthData.deleteBackup(backupKey);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${e.toString()}')),
        );
      }
    }
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all your medications, logs, appointments, and settings. '
          'This action cannot be undone. Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearAllData();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
      // Clear all health data
      await healthData.clearAllData();
      // Clear all preferences
      await preferences.clearAllPreferences();
      // Clear onboarding user data
      await SharedPrefsService.clearUserData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data cleared successfully')),
        );
        // Navigate to onboarding screen
        Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Clear failed: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _exportHealthLogsAsPdf() async {
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);
    final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
    final logs = healthData.logs;
    final appointments = healthData.appointments;
    final medications = healthData.medications;
    final userProfile = healthData.userProfile;
    final condition = preferences.healthCondition;
    
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          // Header Section
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(width: 2)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                                 pw.Text('MediNest Health Report', 
                     style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                                 pw.Text('Generated on ${_formatDate(DateTime.now())}', 
                     style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                if (userProfile != null) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('Patient: ${userProfile.name}', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Email: ${userProfile.email}', style: pw.TextStyle(fontSize: 14)),
                ],
                if (condition.isNotEmpty && condition != 'None') ...[
                  pw.SizedBox(height: 8),
                  pw.Text('Primary Condition: $condition', 
                      style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 24),
          
          // Health Summary Section
          _buildHealthSummarySection(healthData, condition),
          pw.SizedBox(height: 20),
          
          // Medications Section
          _buildMedicationsSection(medications),
          pw.SizedBox(height: 20),
          
          // Upcoming Appointments Section
          _buildAppointmentsSection(appointments),
          pw.SizedBox(height: 20),
          
          // Health Logs Section
          _buildHealthLogsSection(logs),
          pw.SizedBox(height: 20),
          
          // Condition-Specific Vitals Section
          _buildConditionSpecificVitalsSection(healthData, condition),
          
          // Footer
          pw.SizedBox(height: 30),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 1)),
            ),
            child: pw.Column(
                             children: [
                 pw.Text('This report was generated by MediNest', 
                     style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                 pw.Text('Please consult with your healthcare provider for medical advice.', 
                     style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
               ],
            ),
          ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildHealthSummarySection(HealthDataProvider healthData, String condition) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Health Summary', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
                 pw.Container(
           padding: const pw.EdgeInsets.all(12),
           decoration: pw.BoxDecoration(
             color: PdfColors.grey100,
             borderRadius: pw.BorderRadius.circular(8),
           ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Medications:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${healthData.medications.length}'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Current Streak:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${healthData.currentStreak} days'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Longest Streak:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${healthData.longestStreak} days'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Health Logs:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${healthData.logs.length}'),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Upcoming Appointments:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${healthData.upcomingAppointments.length}'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMedicationsSection(List<Medication> medications) {
    final today = DateTime.now();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Medication Schedule & Status', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Today\'s medication status: ${_formatDate(today).split(' ')[0]}', 
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (medications.isEmpty)
          pw.Text('No medications currently prescribed.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Medication Name', 'Scheduled Time', 'Status Today', 'Notes'],
            data: medications.map((med) => [
              med.name,
              med.time,
              _getMedicationStatusForToday(med),
              med.reminderTime != null && med.reminderTime != med.time 
                  ? 'Reminder: ${med.reminderTime}' 
                  : 'No special reminder',
            ]).toList(),
          ),
      ],
    );
  }

  String _getMedicationStatusForToday(Medication medication) {
    // This should check against today's logs to see if the medication was taken
    // For now, we'll use the medication's taken status, but this could be enhanced
    // to check against actual log entries for today
    final now = DateTime.now();
    final timeStr = medication.reminderTime ?? medication.time;
    
    // Parse the time to see if it's past the scheduled time
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
      
      final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      
      if (medication.taken) {
        return '✓ Taken';
      } else if (now.isAfter(scheduledTime)) {
        return '✗ Missed';
      } else {
        return '⏳ Pending';
      }
    } catch (e) {
      return medication.taken ? '✓ Taken' : '⏳ Pending';
    }
  }

  pw.Widget _buildAppointmentsSection(List<Appointment> appointments) {
    final upcomingAppointments = appointments
        .where((appt) => appt.dateTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Upcoming Appointments', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        if (upcomingAppointments.isEmpty)
          pw.Text('No upcoming appointments scheduled.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date & Time', 'Title', 'Location', 'Notes'],
            data: upcomingAppointments.map((appt) => [
              _formatDate(appt.dateTime),
              appt.title,
              appt.location.isNotEmpty ? appt.location : 'Not specified',
              appt.notes.isNotEmpty ? appt.notes : 'No notes',
            ]).toList(),
          ),
      ],
    );
  }

  pw.Widget _buildHealthLogsSection(List<LogEntry> logs) {
    // Sort logs by date (most recent first)
    final sortedLogs = List<LogEntry>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    // Filter logs that have feelings or symptoms
    final feelingsAndSymptomsLogs = sortedLogs.where((log) => 
      (log.feeling != null && log.feeling!.isNotEmpty) || 
      (log.symptoms != null && log.symptoms!.isNotEmpty)
    ).toList();
    
    // Other health logs (medication, general logs, etc.)
    final otherLogs = sortedLogs.where((log) => 
      (log.feeling == null || log.feeling!.isEmpty) && 
      (log.symptoms == null || log.symptoms!.isEmpty)
    ).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Patient Feelings & Symptoms Section
        pw.Text('Patient Feelings & Symptoms', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('How the patient has been feeling and symptoms experienced', 
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (feelingsAndSymptomsLogs.isEmpty)
          pw.Text('No feelings or symptoms have been logged.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date', 'Feeling/Mood', 'Symptoms Experienced', 'Additional Notes'],
            data: feelingsAndSymptomsLogs.map((log) => [
              _formatDate(log.date).split(' ')[0], // Just date, no time
              log.feeling ?? 'Not specified',
              (log.symptoms != null && log.symptoms!.isNotEmpty) 
                  ? log.symptoms!.join(', ') 
                  : 'No symptoms reported',
              log.description.isNotEmpty ? log.description : 'No additional notes',
            ]).toList(),
          ),
        
        pw.SizedBox(height: 24),
        
        // Other Health Activities Section
        pw.Text('Other Health Activities', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Medication logs, general health activities, and other entries', 
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (otherLogs.isEmpty)
          pw.Text('No other health activities logged.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date & Time', 'Activity Type', 'Description'],
            data: otherLogs.take(10).map((log) => [ // Limit to recent 10 entries
              _formatDate(log.date),
              _getActivityTypeDisplay(log.type),
              log.description,
            ]).toList(),
          ),
      ],
    );
  }

  String _getActivityTypeDisplay(String type) {
    switch (type.toLowerCase()) {
      case 'medication':
        return 'Medication';
      case 'daily':
        return 'Daily Check-in';
      case 'vital':
        return 'Vital Signs';
      case 'exercise':
        return 'Exercise';
      case 'diet':
        return 'Diet/Nutrition';
      default:
        return type.toUpperCase();
    }
  }

  pw.Widget _buildConditionSpecificVitalsSection(HealthDataProvider healthData, String condition) {
    final today = DateTime.now();
    final last7Days = List.generate(7, (index) => today.subtract(Duration(days: index)));
    
    List<pw.Widget> vitalsWidgets = [];
    
    // Add condition-specific vital tracking
    switch (condition) {
      case 'Hypertension':
      case 'Heart Disease':
        vitalsWidgets.add(_buildBloodPressureTable(healthData, last7Days));
        break;
      case 'Diabetes':
        vitalsWidgets.add(_buildBloodSugarTable(healthData, last7Days));
        break;
      case 'Asthma':
      case 'COPD':
        vitalsWidgets.add(_buildPeakFlowTable(healthData, last7Days));
        break;
    }
    
    // Always include water intake for all conditions
    vitalsWidgets.add(_buildWaterIntakeTable(healthData, last7Days));
    
    if (vitalsWidgets.isEmpty) {
      return pw.SizedBox.shrink();
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Condition-Specific Vitals (Last 7 Days)', 
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        ...vitalsWidgets,
      ],
    );
  }

  pw.Widget _buildBloodPressureTable(HealthDataProvider healthData, List<DateTime> dates) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Blood Pressure Readings', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Systolic', 'Diastolic', 'Status'],
          data: dates.map((date) {
            final bp = healthData.getBloodPressure(date);
            String status = '-';
            if (bp != null) {
              if (bp[0] >= 140 || bp[1] >= 90) status = 'High';
              else if (bp[0] >= 130 || bp[1] >= 80) status = 'Elevated';
              else status = 'Normal';
            }
            return [
              '${date.day}/${date.month}/${date.year}',
              bp != null ? '${bp[0]} mmHg' : 'Not recorded',
              bp != null ? '${bp[1]} mmHg' : 'Not recorded',
              status,
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildBloodSugarTable(HealthDataProvider healthData, List<DateTime> dates) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Blood Sugar Readings', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Blood Sugar', 'Status'],
          data: dates.map((date) {
            final sugar = healthData.getBloodSugar(date);
            String status = '-';
            if (sugar != null) {
              if (sugar >= 180) status = 'High';
              else if (sugar <= 70) status = 'Low';
              else status = 'Normal';
            }
            return [
              '${date.day}/${date.month}/${date.year}',
              sugar != null ? '$sugar mg/dL' : 'Not recorded',
              status,
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildPeakFlowTable(HealthDataProvider healthData, List<DateTime> dates) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Peak Flow Readings', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Peak Flow', 'Status'],
          data: dates.map((date) {
            final peakFlow = healthData.getPeakFlow(date);
            String status = '-';
            if (peakFlow != null) {
              if (peakFlow >= 400) status = 'Good';
              else if (peakFlow >= 250) status = 'Fair';
              else status = 'Poor';
            }
            return [
              '${date.day}/${date.month}/${date.year}',
              peakFlow != null ? '$peakFlow L/min' : 'Not recorded',
              status,
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildWaterIntakeTable(HealthDataProvider healthData, List<DateTime> dates) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Daily Water Intake', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Water Intake', 'Goal Status'],
          data: dates.map((date) {
            final intake = healthData.getWaterIntake(date);
            final goalMet = intake >= 8 ? 'Goal Met' : 'Below Goal';
            return [
              '${date.day}/${date.month}/${date.year}',
              '$intake glasses',
              goalMet,
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 