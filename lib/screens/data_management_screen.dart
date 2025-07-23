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
import 'package:flutter/services.dart'; // Added for SharedPreferences
import '../services/auth_service.dart'; // Added for AuthService
import '../models/user_profile.dart'; // Added for UserProfile
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences
import '../report_generator.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isImporting = false;
  bool _isCreatingBackup = false;
  bool _isSyncingToCloud = false;
  bool _isRestoringFromCloud = false;
  String? _lastSyncTime;
  String? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastSyncTime = prefs.getString('last_sync_time');
      _syncStatus = prefs.getString('sync_status');
    });
  }

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

                // Debug Section
                _buildSectionHeader(context, 'Debug Tools'),
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.bug_report,
                          color: Colors.orange,
                        ),
                        title: const Text('Debug Data State'),
                        subtitle: const Text('Print current data state to console'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          healthData.debugPrintState();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Debug info printed to console'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.storage,
                          color: Colors.blue,
                        ),
                        title: const Text('Check SharedPreferences'),
                        subtitle: const Text('Check what data is stored locally'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await healthData.hasDataInSharedPreferences();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('SharedPreferences check completed - see console'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.add_circle,
                          color: Colors.green,
                        ),
                        title: const Text('Add Sample Data'),
                        subtitle: const Text('Add test medications and logs'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          // Add sample medications
                          final sampleMedication = Medication(
                            name: 'Test Medication',
                            time: '08:00 AM',
                            reminderTime: '08:00 AM',
                          );
                          await healthData.addMedication(sampleMedication);
                          
                          // Add sample log
                          final sampleLog = LogEntry(
                            date: DateTime.now(),
                            description: 'Took Test Medication',
                            type: 'medication',
                          );
                          await healthData.addLog(sampleLog);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sample data added successfully'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
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
                      // Sync Status Display
                      if (_lastSyncTime != null || _syncStatus != null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _getSyncStatusColor().withOpacity(0.1),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getSyncStatusIcon(),
                                color: _getSyncStatusColor(),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getSyncStatusText(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _getSyncStatusColor(),
                                      ),
                                    ),
                                    if (_lastSyncTime != null)
                                      Text(
                                        'Last sync: $_lastSyncTime',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _getSyncStatusColor().withOpacity(0.7),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ListTile(
                        leading: Icon(
                          Icons.cloud_upload,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Save & Sync to Cloud'),
                        subtitle: const Text('Save locally first, then attempt cloud sync'),
                        trailing: _isSyncingToCloud
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isSyncingToCloud ? null : _syncToCloud,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.cloud_download,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Restore from Cloud'),
                        subtitle: const Text('Download data from Firebase'),
                        trailing: _isRestoringFromCloud
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: _isRestoringFromCloud ? null : _restoreFromCloud,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.backup,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Create Local Backup'),
                        subtitle: const Text('Save a backup of your data locally'),
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
                        title: const Text('Restore from Local Backup'),
                        subtitle: const Text('Load data from a local backup'),
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
                          await healthData.forceReloadData();
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
                          Icons.bug_report,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Diagnose Firestore'),
                        subtitle: const Text('Test Firestore connectivity'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await _diagnoseFirestore();
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.description,
                          color: preferences.primaryColor,
                        ),
                        title: const Text('Generate Project Report'),
                        subtitle: const Text('Create PDF report for submission'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          try {
                            await ReportGenerator.generateProjectReport();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Project report generated successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error generating report: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
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
    var userProfile = healthData.userProfile;
    var condition = preferences.healthCondition;
    
    // If Firestore profile is not available, try to load from SharedPreferences
    if (userProfile == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final name = prefs.getString('user_name');
        final age = prefs.getString('user_age');
        final healthCondition = prefs.getString('user_condition');
        
        if (name != null) {
          final authService = Provider.of<AuthService>(context, listen: false);
          final currentUser = authService.currentUser;
          
          if (currentUser != null) {
            userProfile = UserProfile(
              uid: currentUser.uid,
              name: name,
              email: currentUser.email ?? '',
              age: age,
              healthCondition: healthCondition,
              createdAt: DateTime.now(),
            );
            print('PDF Export - Loaded profile from SharedPreferences: ${userProfile.name}');
          }
        }
      } catch (e) {
        print('PDF Export - Error loading profile from SharedPreferences: $e');
      }
    }
    
    // Use condition from SharedPreferences if available
    if (condition.isEmpty || condition == 'None') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final healthCondition = prefs.getString('user_condition');
        if (healthCondition != null && healthCondition.isNotEmpty) {
          condition = healthCondition;
          print('PDF Export - Loaded condition from SharedPreferences: $condition');
        }
      } catch (e) {
        print('PDF Export - Error loading condition from SharedPreferences: $e');
      }
    }
    
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
                pw.Text('MediNest Comprehensive Health Report', 
                    style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Generated on ${_formatDate(DateTime.now())}', 
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
                if (userProfile != null) ...[
                  pw.SizedBox(height: 12),
                  pw.Text('Patient: ${userProfile.name}', style: pw.TextStyle(fontSize: 16)),
                  pw.Text('Email: ${userProfile.email}', style: pw.TextStyle(fontSize: 14)),
                  if (userProfile.age != null && userProfile.age!.isNotEmpty)
                    pw.Text('Age: ${userProfile.age}', style: pw.TextStyle(fontSize: 14)),
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
          
          // Complete Medications Section with Status
          _buildCompleteMedicationsSection(medications, healthData),
          pw.SizedBox(height: 20),
          
          // Medication Adherence Report
          _buildMedicationAdherenceReport(medications, healthData),
          pw.SizedBox(height: 20),
          
          // Complete Appointments Section (Past & Future)
          _buildCompleteAppointmentsSection(appointments),
          pw.SizedBox(height: 20),
          
          // Comprehensive Health Logs Section
          _buildComprehensiveHealthLogsSection(logs),
          pw.SizedBox(height: 20),
          
          // Condition-Specific Vitals Section (Enhanced)
          _buildEnhancedConditionSpecificVitalsSection(healthData, condition),
          pw.SizedBox(height: 20),
          
          // Streak and Compliance Analytics
          _buildStreakAnalyticsSection(healthData),
          
          // Footer
          pw.SizedBox(height: 30),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(width: 1)),
            ),
            child: pw.Column(
              children: [
                pw.Text('This comprehensive report was generated by MediNest', 
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

  pw.Widget _buildCompleteMedicationsSection(List<Medication> medications, HealthDataProvider healthData) {
    final today = DateTime.now();
    final todayLogs = healthData.logs.where((log) => 
      log.date.year == today.year && 
      log.date.month == today.month && 
      log.date.day == today.day
    ).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Complete Medication Schedule & Status', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
              _getMedicationStatusForToday(med, todayLogs),
              med.reminderTime != null && med.reminderTime != med.time 
                  ? 'Reminder: ${med.reminderTime}' 
                  : 'No special reminder',
            ]).toList(),
          ),
      ],
    );
  }

  String _getMedicationStatusForToday(Medication medication, List<LogEntry> todayLogs) {
    final now = DateTime.now();
    final timeStr = medication.reminderTime ?? medication.time;
    
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

  pw.Widget _buildMedicationAdherenceReport(List<Medication> medications, HealthDataProvider healthData) {
    final today = DateTime.now();
    final todayLogs = healthData.logs.where((log) => 
      log.date.year == today.year && 
      log.date.month == today.month && 
      log.date.day == today.day
    ).toList();

    final totalMedications = medications.length;
    final totalTodayTaken = todayLogs.where((log) => 
      log.type == 'medication' && log.description.startsWith('Took')
    ).length;
    final totalTodayMissed = todayLogs.where((log) => 
      log.type == 'medication' && log.description.startsWith('Missed')
    ).length;
    final adherencePercentage = totalMedications > 0 ? (totalTodayTaken * 100 / totalMedications).round() : 0;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Medication Adherence Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Total Medications: $totalMedications'),
        pw.SizedBox(height: 4),
        pw.Text('Medications Taken Today: $totalTodayTaken'),
        pw.SizedBox(height: 4),
        pw.Text('Medications Missed Today: $totalTodayMissed'),
        pw.SizedBox(height: 12),
        pw.Text('Today\'s Adherence: $adherencePercentage%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _buildCompleteAppointmentsSection(List<Appointment> appointments) {
    final upcomingAppointments = appointments
        .where((appt) => appt.dateTime.isAfter(DateTime.now()))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    
    final pastAppointments = appointments
        .where((appt) => appt.dateTime.isBefore(DateTime.now()))
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Complete Appointments (Past & Future)', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
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
        pw.SizedBox(height: 12),
        if (pastAppointments.isEmpty)
          pw.Text('No past appointments.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date & Time', 'Title', 'Location', 'Notes'],
            data: pastAppointments.map((appt) => [
              _formatDate(appt.dateTime),
              appt.title,
              appt.location.isNotEmpty ? appt.location : 'Not specified',
              appt.notes.isNotEmpty ? appt.notes : 'No notes',
            ]).toList(),
          ),
      ],
    );
  }

  pw.Widget _buildComprehensiveHealthLogsSection(List<LogEntry> logs) {
    // Sort logs by date (most recent first)
    final sortedLogs = List<LogEntry>.from(logs)
      ..sort((a, b) => b.date.compareTo(a.date));
    
    // Filter logs by type for better organization
    final medicationLogs = sortedLogs.where((log) => log.type == 'medication').toList();
    final feelingLogs = sortedLogs.where((log) => 
      (log.feeling != null && log.feeling!.isNotEmpty) || 
      (log.symptoms != null && log.symptoms!.isNotEmpty)
    ).toList();
    final otherLogs = sortedLogs.where((log) => 
      log.type != 'medication' && 
      (log.feeling == null || log.feeling!.isEmpty) && 
      (log.symptoms == null || log.symptoms!.isEmpty)
    ).toList();
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Medication Logs Section
        pw.Text('Medication Logs', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Complete medication adherence history', 
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (medicationLogs.isEmpty)
          pw.Text('No medication logs recorded.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date & Time', 'Medication Action', 'Details'],
            data: medicationLogs.take(20).map((log) => [ // Show last 20 medication logs
              _formatDate(log.date),
              log.description.startsWith('Took') ? 'Taken' : 'Missed',
              log.description,
            ]).toList(),
          ),
        
        pw.SizedBox(height: 24),
        
        // Patient Feelings & Symptoms Section
        pw.Text('Patient Feelings & Symptoms', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('How the patient has been feeling and symptoms experienced', 
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (feelingLogs.isEmpty)
          pw.Text('No feelings or symptoms have been logged.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date', 'Feeling/Mood', 'Symptoms Experienced', 'Additional Notes'],
            data: feelingLogs.take(15).map((log) => [ // Show last 15 feeling logs
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
        pw.Text('General health activities, vital signs, and other entries', 
            style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        if (otherLogs.isEmpty)
          pw.Text('No other health activities logged.')
        else
          pw.Table.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headers: ['Date & Time', 'Activity Type', 'Description'],
            data: otherLogs.take(15).map((log) => [ // Show last 15 other logs
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

  pw.Widget _buildEnhancedConditionSpecificVitalsSection(HealthDataProvider healthData, String condition) {
    final today = DateTime.now();
    final last7Days = List.generate(7, (index) => today.subtract(Duration(days: index)));
    
    List<pw.Widget> vitalsWidgets = [];
    
    // Add condition-specific vital tracking for ALL conditions
    switch (condition.toLowerCase()) {
      case 'hypertension':
      case 'heart disease':
        vitalsWidgets.add(_buildBloodPressureTable(healthData, last7Days));
        break;
      case 'diabetes':
        vitalsWidgets.add(_buildBloodSugarTable(healthData, last7Days));
        break;
      case 'asthma':
      case 'copd':
        vitalsWidgets.add(_buildPeakFlowTable(healthData, last7Days));
        break;
      case 'sickle cell disease':
        vitalsWidgets.add(_buildWaterIntakeTable(healthData, last7Days));
        vitalsWidgets.add(_buildPainLevelTable(healthData, last7Days));
        break;
      default:
        // For any other condition, show water intake as general health metric
        vitalsWidgets.add(_buildWaterIntakeTable(healthData, last7Days));
        break;
    }
    
    // Always include water intake for all conditions (except sickle cell which already has it)
    if (!condition.toLowerCase().contains('sickle cell')) {
      vitalsWidgets.add(_buildWaterIntakeTable(healthData, last7Days));
    }
    
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
              if (bp[0] >= 140 || bp[1] >= 90) {
                status = 'High';
              } else if (bp[0] >= 130 || bp[1] >= 80) status = 'Elevated';
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
              if (sugar >= 180) {
                status = 'High';
              } else if (sugar <= 70) status = 'Low';
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
              if (peakFlow >= 400) {
                status = 'Good';
              } else if (peakFlow >= 250) status = 'Fair';
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

  pw.Widget _buildPainLevelTable(HealthDataProvider healthData, List<DateTime> dates) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Pain Level Readings', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Pain Level', 'Status'],
          data: dates.map((date) {
            final painLevel = healthData.getPainLevel(date);
            String status = '-';
            if (painLevel != null) {
              if (painLevel >= 7) {
                status = 'High';
              } else if (painLevel >= 3) status = 'Moderate';
              else status = 'Low';
            }
            return [
              '${date.day}/${date.month}/${date.year}',
              painLevel != null ? '$painLevel/10' : 'Not recorded',
              status,
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  pw.Widget _buildStreakAnalyticsSection(HealthDataProvider healthData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Streak and Compliance Analytics', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('Current Medication Streak: ${healthData.currentStreak} days'),
        pw.SizedBox(height: 4),
        pw.Text('Longest Medication Streak: ${healthData.longestStreak} days'),
        pw.SizedBox(height: 4),
        pw.Text('Total Health Logs: ${healthData.logs.length}'),
        pw.SizedBox(height: 4),
        pw.Text('Total Appointments: ${healthData.appointments.length}'),
        pw.SizedBox(height: 12),
        pw.Text('Missed Doses: ${healthData.missedDoses}'),
        pw.SizedBox(height: 4),
        pw.Text('Weekly Appointments: ${healthData.weeklyAppointments}'),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getSyncStatusColor() {
    if (_syncStatus == 'success') {
      return Colors.green;
    } else if (_syncStatus == 'failed') {
      return Colors.orange;
    } else if (_syncStatus == 'error') {
      return Colors.red;
    } else {
      return Colors.blue;
    }
  }

  IconData _getSyncStatusIcon() {
    if (_syncStatus == 'success') {
      return Icons.check_circle;
    } else if (_syncStatus == 'failed') {
      return Icons.warning;
    } else if (_syncStatus == 'error') {
      return Icons.error;
    } else {
      return Icons.cloud_sync;
    }
  }

  String _getSyncStatusText() {
    if (_syncStatus == 'success') {
      return '✅ Data synced to cloud successfully!';
    } else if (_syncStatus == 'failed') {
      return '⚠️ Cloud sync failed, but data is saved locally';
    } else if (_syncStatus == 'error') {
      return '❌ Sync failed. Please check your internet connection or try again later.';
    } else {
      return '📱 Data saved locally. Tap to attempt cloud sync.';
    }
  }

  Future<void> _syncToCloud() async {
    setState(() {
      _isSyncingToCloud = true;
      _syncStatus = null; // Clear previous status
    });

    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final userProfile = healthData.userProfile;

      if (userProfile == null) {
        throw Exception('User profile not found. Please log in.');
      }

      // Step 1: Ensure all data is saved to SharedPreferences first
      print('DataManagement - Ensuring all data is saved locally...');
      await healthData.saveAllDataToSharedPreferences();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data saved locally! Attempting cloud sync...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Step 2: Attempt Firestore sync (optional)
      try {
        print('DataManagement - Attempting Firestore sync...');
        await healthData.syncDataToFirestore(userProfile);
        await _loadSyncStatus(); // Refresh status after sync

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Data synced to cloud successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (firestoreError) {
        print('DataManagement - Firestore sync failed: $firestoreError');
        
        // Update sync status to show failure
        await prefs.setString('sync_status', 'failed');
        await prefs.setString('last_sync_time', DateTime.now().toString());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Cloud sync failed, but data is saved locally. Error: ${firestoreError.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSyncingToCloud = false;
      });
    }
  }

  Future<void> _restoreFromCloud() async {
    setState(() {
      _isRestoringFromCloud = true;
      _syncStatus = null; // Clear previous status
    });

    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      final userProfile = healthData.userProfile;

      if (userProfile == null) {
        throw Exception('User profile not found. Please log in.');
      }

      await healthData.restoreDataFromFirestore(userProfile);
      await _loadSyncStatus(); // Refresh status after restore

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored from cloud successfully!')),
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
        _isRestoringFromCloud = false;
      });
    }
  }

  Future<void> _diagnoseFirestore() async {
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);
    final prefs = await SharedPreferences.getInstance();
    final userProfile = healthData.userProfile;

    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User profile not found. Please log in to diagnose Firestore.')),
      );
      return;
    }

    try {
      await healthData.testFirestoreConnection(userProfile);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firestore connection successful!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Firestore connection failed: ${e.toString()}')),
      );
    }
  }
} 