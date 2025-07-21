import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/log_entry.dart';
import '../widgets/loading_widget.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../providers/user_preferences_provider.dart';

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
    // Find and delete any existing log for this med/date
    final logToDelete = provider.logs.firstWhere(
      (l) => l.type == 'medication' &&
             l.date.year == date.year &&
             l.date.month == date.month &&
             l.date.day == date.day &&
             (l.description == 'Took ${med.name}' || l.description == 'Missed ${med.name}'),
      orElse: () => LogEntry(id: null, date: DateTime.now(), description: '', type: ''), // Dummy
    );
    if (logToDelete.id != null) {
      await provider.deleteLog(logToDelete.id!);
    }
    // Add a new log
    await provider.addLog(LogEntry(
      date: date,
      description: taken ? 'Took ${med.name}' : 'Missed ${med.name}',
      type: 'medication',
    ));
  }

  // 2. Remove the old `getMedicationTakenStatus`, `_getLogTypeColor`, and `_showEditDialog` methods.
  // 3. Update the ListView.builder to directly check the log status.
  //    (This will be a larger change, including checkbox logic)

  @override
  Widget build(BuildContext context) {
    return Consumer2<HealthDataProvider, UserPreferencesProvider>(
      builder: (context, healthData, userPrefs, child) {
        Widget body;
        if (healthData.logs == null || healthData.medications == null) {
          body = const LoadingWidget(message: 'Loading your logs...');
        } else if (healthData.errorMessage != null && healthData.logs!.isEmpty) {
          body = _buildErrorWidget(context, healthData.errorMessage!, healthData.clearError);
        } else if (healthData.logs!.isEmpty && healthData.medications!.isEmpty) {
          body = _buildEmptyState();
        } else {
          body = _buildLogContent(context, healthData, userPrefs);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Health Logs')),
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
                    onPressed: () => healthData.decrementWaterIntake(_selectedDate),
                  ),
                  Text(
                    '${healthData.getWaterIntake(_selectedDate)} glasses',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => healthData.incrementWaterIntake(_selectedDate),
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
          if (healthData.medications!.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: Center(
                child: Text('No medications scheduled. Add medications on the Schedule page.'),
              ),
            )
          else
            _buildMedicationChecklist(healthData, healthData.medications!),
            
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
                      final sys = int.tryParse(_bpSysController.text);
                      final dia = int.tryParse(_bpDiaController.text);
                      if (sys != null && dia != null) {
                        await healthData.setBloodPressure(_selectedDate, sys, dia);
                        setState(() {});
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
                      final sugar = int.tryParse(_sugarController.text);
                      if (sugar != null) {
                        await healthData.setBloodSugar(_selectedDate, sugar);
                        setState(() {});
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
                      final pf = int.tryParse(_peakFlowController.text);
                      if (pf != null) {
                        await healthData.setPeakFlow(_selectedDate, pf);
                        setState(() {});
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
          // Summary
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary for the day:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...healthData.medications!.map((med) {
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
                  return Text('${med.name}: ${isPast ? 'Missed' : 'Not logged'}');
                }).toList(),
                // Show latest daily log for the date
                Builder(
                  builder: (context) {
                    final dailyLogs = healthData.logs!.where((l) => l.type == 'daily' && l.date.year == _selectedDate.year && l.date.month == _selectedDate.month && l.date.day == _selectedDate.day).toList();
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
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: medications.length,
      itemBuilder: (context, idx) {
        final med = medications[idx];
        // Directly find the log for the current med and date
        final logForMed = healthData.logs!.firstWhere(
          (l) => l.type == 'medication' &&
                 l.date.year == _selectedDate.year &&
                 l.date.month == _selectedDate.month &&
                 l.date.day == _selectedDate.day &&
                 (l.description == 'Took ${med.name}' || l.description == 'Missed ${med.name}'),
          orElse: () => LogEntry(id: null, date: DateTime.now(), description: '', type: ''), // Dummy
        );
        final bool? taken = logForMed.id == null ? null : logForMed.description.startsWith('Took');
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: Icon(Icons.medication, color: taken == null ? Colors.grey : (taken ? Colors.green : Colors.red)),
            title: Text(med.name),
            subtitle: Text('Time: ${med.time}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: taken,
                  tristate: true,
                  onChanged: (val) async {
                    await setMedicationTakenStatus(healthData, med, _selectedDate, val ?? false);
                  },
                  activeColor: Colors.green,
                ),
                if (taken == true)
                  const Text('Took', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                if (taken == false)
                  const Text('Missed', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                if (taken == null)
                  const Text('Not logged', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
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