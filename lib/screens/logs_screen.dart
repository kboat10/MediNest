import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/log_entry.dart';
import '../widgets/loading_widget.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import 'package:collection/collection.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _feelingController = TextEditingController();
  final List<String> _allSymptoms = [
    'Headache', 'Fever', 'Nausea', 'Fatigue', 'Cough', 'Sore throat', 'Shortness of breath', 'Muscle pain', 'No symptoms',
  ];
  List<String> _selectedSymptoms = [];

  @override
  void dispose() {
    _searchController.dispose();
    _feelingController.dispose();
    super.dispose();
  }

  // Helper to get medication log status for a given date and medication
  bool? getMedicationTakenStatus(List<LogEntry> logs, Medication med, DateTime date) {
    final log = logs.firstWhereOrNull(
      (l) => l.type == 'medication' &&
              l.date.year == date.year &&
              l.date.month == date.month &&
              l.date.day == date.day &&
              (l.description == 'Took ${med.name}' || l.description == 'Missed ${med.name}'),
    );
    if (log == null) return null;
    return log.description.startsWith('Took');
  }

  Future<void> setMedicationTakenStatus(HealthDataProvider provider, Medication med, DateTime date, bool taken) async {
    // Remove any existing log for this med/date
    final logs = provider.logs;
    final idx = logs.indexWhere((l) =>
      l.type == 'medication' &&
      l.date.year == date.year &&
      l.date.month == date.month &&
      l.date.day == date.day &&
      (l.description == 'Took ${med.name}' || l.description == 'Missed ${med.name}')
    );
    if (idx != -1) {
      await provider.deleteLog(idx);
    }
    await provider.addLog(LogEntry(
      date: date,
      description: taken ? 'Took ${med.name}' : 'Missed ${med.name}',
      type: 'medication',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final healthData = Provider.of<HealthDataProvider>(context);
    final logs = healthData.logs;
    final medications = healthData.medications;
    
    return LoadingOverlay(
      isLoading: healthData.isLoading,
      loadingMessage: 'Updating logs...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Health Logs')),
        body: SingleChildScrollView(
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
                        if (_feelingController.text.trim().isEmpty && _selectedSymptoms.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a feeling or select at least one symptom.')),
                          );
                          return;
                        }
                        await healthData.addDailyFeelingLog(
                          _selectedDate,
                          _feelingController.text.trim(),
                          List<String>.from(_selectedSymptoms),
                        );
                        setState(() {
                          _feelingController.clear();
                          _selectedSymptoms.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
              // Medication checklist for the day
              if (medications.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 32.0),
                  child: Center(
                    child: Text('No medications scheduled. Add medications on the Schedule page.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: medications.length,
                  itemBuilder: (context, idx) {
                    final med = medications[idx];
                    final taken = getMedicationTakenStatus(logs, med, _selectedDate);
                    final now = DateTime.now();
                    // Parse med.reminderTime or med.time to DateTime for today
                    String timeStr = med.reminderTime ?? med.time;
                    final timeParts = timeStr.split(' ');
                    final hm = timeParts[0].split(':');
                    int hour = int.parse(hm[0]);
                    int minute = int.parse(hm[1]);
                    if (timeParts[1] == 'PM' && hour != 12) hour += 12;
                    if (timeParts[1] == 'AM' && hour == 12) hour = 0;
                    final medTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
                    final isPast = now.isAfter(medTime) && _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: Icon(Icons.medication, color: taken == true ? Colors.green : taken == false ? Colors.red : Colors.grey),
                        title: Text(med.name),
                        subtitle: Text('Time: ${med.time}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: taken == true,
                              tristate: true,
                              onChanged: (val) async {
                                await setMedicationTakenStatus(healthData, med, _selectedDate, val ?? false);
                                setState(() {});
                              },
                              activeColor: Colors.green,
                            ),
                            if (taken == true)
                              const Text('Taken', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            if (taken == false)
                              const Text('Missed', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            if (taken == null)
                              const Text('Not logged', style: TextStyle(color: Colors.grey)),
                            // Show 'Missed' checkbox if not taken/missed and time is past
                            if (taken == null && isPast)
                              Row(
                                children: [
                                  const SizedBox(width: 8),
                                  Checkbox(
                                    value: false,
                                    onChanged: (val) async {
                                      await setMedicationTakenStatus(healthData, med, _selectedDate, false);
                                      setState(() {});
                                    },
                                    activeColor: Colors.red,
                                  ),
                                  const Text('Missed?', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              // Summary
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Summary for the day:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...medications.map((med) {
                      final taken = getMedicationTakenStatus(logs, med, _selectedDate);
                      return Text('${med.name}: ${taken == true ? 'Taken' : taken == false ? 'Missed' : 'Not logged'}');
                    }).toList(),
                    // Show latest daily log for the date
                    Builder(
                      builder: (context) {
                        final dailyLogs = logs.where((l) => l.type == 'daily' && l.date.year == _selectedDate.year && l.date.month == _selectedDate.month && l.date.day == _selectedDate.day).toList();
                        if (dailyLogs.isNotEmpty) {
                          final log = dailyLogs.last;
                          return Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Your feeling: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(log.feeling ?? '-'),
                                const SizedBox(height: 4),
                                const Text('Symptoms: ', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(log.symptoms != null && log.symptoms!.isNotEmpty ? log.symptoms!.join(', ') : '-'),
                              ],
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getLogTypeColor(String type) {
    switch (type) {
      case 'medication':
        return Colors.blue;
      case 'appointment':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  void _showEditDialog(BuildContext context, HealthDataProvider healthData, int index, LogEntry log) {
    String? selectedType = log.type;
    final descController = TextEditingController(text: log.description);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Log Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: const [
                DropdownMenuItem(value: 'medication', child: Text('Medication')),
                DropdownMenuItem(value: 'appointment', child: Text('Appointment')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (val) => selectedType = val,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descController.text.isNotEmpty && selectedType != null) {
                Navigator.pop(context);
                await healthData.editLog(
                  index,
                  descController.text,
                  selectedType!,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
} 