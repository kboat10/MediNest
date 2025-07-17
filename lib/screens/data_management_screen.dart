import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import '../providers/health_data_provider.dart';
import '../providers/user_preferences_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/shared_prefs_service.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({Key? key}) : super(key: key);

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _isCreatingBackup = false;
  bool _isRestoring = false;

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

  Future<void> _exportData() async {
    setState(() {
      _isExporting = true;
    });

    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
      
      // Export health data
      final healthDataJson = await healthData.exportData();
      
      // Export preferences
      final preferencesData = {
        'darkMode': preferences.isDarkMode,
        'notificationsEnabled': preferences.notificationsEnabled,
        'medicationReminders': preferences.medicationReminders,
        'appointmentReminders': preferences.appointmentReminders,
        'primaryColor': preferences.primaryColor.value,
        'accentColor': preferences.accentColor.value,
        'fontSize': preferences.fontSize,
      };
      
      final exportData = {
        'healthData': jsonDecode(healthDataJson),
        'preferences': preferencesData,
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0.0',
      };
      
      final jsonString = jsonEncode(exportData);
      final fileName = 'mymedbuddy_export_${DateTime.now().millisecondsSinceEpoch}.json';
      
      // Share the file
      await Share.share(
        jsonString,
        subject: 'MyMedBuddy Data Export',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data exported successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
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
      _isRestoring = true;
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
        _isRestoring = false;
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
    final logs = healthData.logs;
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Health Logs', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 16),
          if (logs.isEmpty)
            pw.Text('No health logs available.')
          else
            pw.Table.fromTextArray(
              headers: ['Date', 'Description', 'Type', 'Feeling', 'Symptoms'],
              data: logs.map((log) => [
                log.date.toIso8601String(),
                log.description,
                log.type,
                log.feeling ?? '-',
                (log.symptoms != null && log.symptoms!.isNotEmpty) ? log.symptoms!.join(', ') : '-',
              ]).toList(),
            ),
        ],
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 