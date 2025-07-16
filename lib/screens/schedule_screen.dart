import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/medication.dart';
import '../widgets/loading_widget.dart';
import '../services/notification_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
    final healthData = Provider.of<HealthDataProvider>(context);
    final meds = healthData.searchMedications(_searchQuery);
    
    return LoadingOverlay(
      isLoading: healthData.isLoading,
      loadingMessage: 'Updating medication...',
      child: Scaffold(
        appBar: AppBar(title: const Text('Medication Schedule')),
        body: Column(
          children: [
            // Search bar
            Container(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search medications...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Error message display
            if (healthData.errorMessage != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        healthData.errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => healthData.clearError(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            
            // Medication list
            Expanded(
              child: meds.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isNotEmpty ? Icons.search_off : Icons.medication_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty 
                                ? 'No medications found'
                                : 'No medications scheduled',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try adjusting your search terms'
                                : 'Tap the + button to add all your medications for the day. You can add as many as you need!',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: meds.length,
                      itemBuilder: (context, index) {
                        final med = meds[index];
                        final originalIndex = healthData.medications.indexOf(med);
                        
                        return Dismissible(
                          key: Key(med.name + med.time),
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
                            await NotificationService().flutterLocalNotificationsPlugin.cancel(med.name.hashCode ^ (med.reminderTime?.hashCode ?? med.time.hashCode));
                            healthData.deleteMedication(originalIndex);
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
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.medication,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                med.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text('Time: ${med.time}\nReminder: ${med.reminderTime ?? med.time}'),
                              onLongPress: () => _showEditDialog(context, healthData, originalIndex, med),
                              onTap: () => _showEditDialog(context, healthData, originalIndex, med),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
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
              await healthData.addMedication(Medication(
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
                id: result['name']!.hashCode ^ result['reminderTime']!.hashCode,
                title: 'Medication Reminder',
                body: 'Time to take ${result['name']}!',
                scheduledTime: scheduledTime.isAfter(now) ? scheduledTime : scheduledTime.add(const Duration(days: 1)),
              );
            }
          },
          child: const Icon(Icons.add),
          tooltip: 'Add Medication',
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, HealthDataProvider healthData, int index, Medication med) {
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
                if (nameController.text.isNotEmpty && selectedTime != null) {
                  Navigator.pop(context);
                  await healthData.editMedication(
                    index,
                    nameController.text,
                    selectedTime!,
                    selectedReminderTime,
                  );
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