import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/medication.dart';
import '../widgets/loading_widget.dart';
import '../services/notification_service.dart';

final Map<String, String> drugFacts = {
  'Aspirin': 'Aspirin is used to reduce pain, fever, or inflammation. It can also prevent blood clots.',
  'Paracetamol': 'Paracetamol is a common painkiller used to treat aches and pain. It can also reduce a high temperature.',
  'Metformin': 'Metformin is used to treat type 2 diabetes and helps control blood sugar levels.',
  'Lisinopril': 'Lisinopril is used to treat high blood pressure and heart failure.',
  'Ventolin': 'Ventolin (salbutamol) is used to relieve symptoms of asthma and COPD.',
  'Folic Acid': 'Folic acid is a B vitamin that helps prevent neural tube defects and supports red blood cell formation. Often prescribed during pregnancy or for certain types of anemia.',
  'Ibuprofen': 'Ibuprofen is a nonsteroidal anti-inflammatory drug (NSAID) used to reduce pain, fever, and inflammation.',
  'Omeprazole': 'Omeprazole is a proton pump inhibitor used to treat acid reflux, heartburn, and stomach ulcers.',
  'Simvastatin': 'Simvastatin is used to lower cholesterol and reduce the risk of heart disease.',
  'Warfarin': 'Warfarin is an anticoagulant (blood thinner) used to prevent blood clots.',
  'Hydrocodone': 'Hydrocodone is an opioid pain medication used to treat moderate to severe pain.',
  'Vitamin D': 'Vitamin D is essential for bone health and immune system function. Often prescribed for deficiency.',
  'Prednisone': 'Prednisone is a corticosteroid used to treat inflammation and autoimmune conditions.',
  'Insulin': 'Insulin is a hormone used to control blood sugar levels in people with diabetes.',
  'Levothyroxine': 'Levothyroxine is used to treat hypothyroidism (underactive thyroid).',
  'Zincovit': 'Zincovit is a multivitamin and mineral supplement containing zinc, vitamins A, B-complex, C, D, and E. It helps boost immunity, supports wound healing, and aids in overall nutritional health. Commonly used to treat vitamin and mineral deficiencies.',
  // Add more as needed
};

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String _searchQuery = '';

  // Helper to generate time options every 30 minutes from 6:00 AM to 10:00 PM
  List<String> getTimeOptions() {
    final List<String> times = [];
    TimeOfDay time = const TimeOfDay(hour: 6, minute: 0);
    while (time.hour < 22 || (time.hour == 22 && time.minute == 0)) {
      final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      final formatted = '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period';
      times.add(formatted);
      int nextMinutes = time.minute + 30;
      int nextHour = time.hour;
      if (nextMinutes >= 60) {
        nextHour += 1;
        nextMinutes = 0;
      }
      time = TimeOfDay(hour: nextHour, minute: nextMinutes);
      if (nextHour > 22) break;
    }
    return times;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthDataProvider>(
      builder: (context, healthData, child) {
        // Debug: Print current state
        print('ScheduleScreen - Current medications count: ${healthData.medications.length}');
        print('ScheduleScreen - isLoading: ${healthData.isLoading}');
        
        // Decide what to show based on the provider's state
        Widget body;
        if (healthData.isLoading) {
          body = LoadingWidget(message: 'Loading medications...');
        } else if (healthData.errorMessage != null && healthData.medications.isEmpty) {
          // Show error only if there are no meds to display
          body = _buildErrorWidget(context, healthData.errorMessage!, healthData.clearError);
        } else if (healthData.medications.isEmpty) {
          body = _buildEmptyState();
        } else {
          body = _buildMedicationList(healthData, healthData.medications);
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Medication Schedule')),
          body: body,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddDialog(context, healthData),
            tooltip: 'Add Medication',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  // Extracted Widgets for Clarity

  Widget _buildMedicationList(HealthDataProvider healthData, List<Medication> meds) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80), // Padding for FAB
      itemCount: meds.length,
      itemBuilder: (context, index) {
        final med = meds[index];
        return Dismissible(
          key: Key(med.id ?? med.name + med.time),
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(
              Icons.delete,
              color: Colors.white,
              size: 30,
            ),
          ),
          direction: DismissDirection.endToStart,
          confirmDismiss: (direction) async {
            return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete Medication'),
                content: Text('Are you sure you want to delete "${med.name}"?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
          },
          onDismissed: (direction) async {
            if (med.id != null) {
              await NotificationService().flutterLocalNotificationsPlugin.cancel(med.id!.hashCode);
              await healthData.deleteMedication(med.id!);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${med.name} deleted'),
                  action: SnackBarAction(
                    label: 'Undo',
                    onPressed: () {
                      healthData.addMedication(med);
                    },
                  ),
                ),
              );
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(51),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.medication,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              title: Row(
                children: [
                  Expanded(child: Text(med.name)),
                  IconButton(
                    icon: Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
                    tooltip: 'Drug Fact',
                    onPressed: () {
                      final fact = drugFacts[med.name] ?? 'No fact available for this medication.';
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('About ${med.name}'),
                          content: Text(fact),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              subtitle: Text('Time: ${med.time}\nReminder: ${med.reminderTime ?? med.time}'),
              onLongPress: () => _showEditDialog(context, healthData, med),
              onTap: () => _showEditDialog(context, healthData, med),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.medication_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No medications scheduled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Tap the + button to add your medications and set reminders.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
            onPressed: onClear, // This could be changed to a retry function later
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  // Renamed from _showAddDialog to avoid confusion with the method above it
  void _showAddDialog(BuildContext context, HealthDataProvider healthData) async {
    final result = await showDialog<Map<String, String>>(
              context: context,
              builder: (context) {
                final nameController = TextEditingController();
                String? selectedTime;
                String? selectedReminderTime;
                final timeOptions = getTimeOptions();
                return StatefulBuilder(
                  builder: (context, setState) => AlertDialog(
                    title: const Text('Add Medication'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Medication Name',
                            prefixIcon: Icon(Icons.medication),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedTime,
                          items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => selectedTime = val),
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedReminderTime ?? selectedTime,
                          items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => selectedReminderTime = val),
                          decoration: const InputDecoration(
                            labelText: 'Reminder Time',
                            prefixIcon: Icon(Icons.notifications_active),
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
                        onPressed: () {
                          if (nameController.text.isNotEmpty && selectedTime != null) {
                            Navigator.pop(context, {
                              'name': nameController.text,
                              'time': selectedTime!,
                              'reminderTime': selectedReminderTime ?? selectedTime!,
                            });
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                );
              },
            );
    if (result != null) {
      final newMed = await healthData.addMedication(Medication(
        name: result['name']!,
        time: result['time']!,
        reminderTime: result['reminderTime']!,
      ));
      // Schedule notification
      final now = DateTime.now();
      final reminderParts = result['reminderTime']!.split(' ');
      final timeParts = reminderParts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      if (reminderParts[1] == 'PM' && hour != 12) hour += 12;
      if (reminderParts[1] == 'AM' && hour == 12) hour = 0;
      final scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
      await NotificationService().scheduleNotification(
        id: newMed.id.hashCode,
        title: 'Medication Reminder',
        body: 'Time to take ${result['name']}!',
        scheduledTime: scheduledTime.isAfter(now) ? scheduledTime : scheduledTime.add(const Duration(days: 1)),
      );
    }
  }

  void _showEditDialog(BuildContext context, HealthDataProvider healthData, Medication med) {
    final nameController = TextEditingController(text: med.name);
    String? selectedTime = med.time;
    String? selectedReminderTime = med.reminderTime;
    final timeOptions = getTimeOptions();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Medication'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  prefixIcon: Icon(Icons.medication),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedTime,
                items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => selectedTime = val),
                decoration: const InputDecoration(
                  labelText: 'Time',
                  prefixIcon: Icon(Icons.access_time),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReminderTime ?? selectedTime,
                items: timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => selectedReminderTime = val),
                decoration: const InputDecoration(
                  labelText: 'Reminder Time',
                  prefixIcon: Icon(Icons.notifications_active),
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
                if (nameController.text.isNotEmpty && selectedTime != null && med.id != null) {
                  final updatedMed = med.copyWith(
                    name: nameController.text,
                    time: selectedTime!,
                    reminderTime: selectedReminderTime,
                  );
                  await healthData.updateMedication(med.id!, updatedMed);
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
} 