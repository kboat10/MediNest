import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/appointment.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../widgets/loading_widget.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({Key? key}) : super(key: key);

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Appointment? _deletedAppointment;
  int? _deletedIndex;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthDataProvider>(
      builder: (context, healthData, child) {
        Widget body;
        if (healthData.appointments == null) {
          body = const LoadingWidget(message: 'Loading appointments...');
        } else if (healthData.errorMessage != null && healthData.appointments!.isEmpty) {
          body = _buildErrorWidget(context, healthData.errorMessage!, healthData.clearError);
        } else if (healthData.appointments!.isEmpty) {
          body = _buildEmptyState();
        } else {
          body = _buildAppointmentsList(context, healthData, healthData.appointments!);
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Appointments'),
            elevation: 0,
          ),
          body: body,
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showAddAppointmentDialog(context, healthData),
            child: const Icon(Icons.add),
            tooltip: 'Add Appointment',
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsList(BuildContext context, HealthDataProvider healthData, List<Appointment> appointments) {
    // This can contain the search bar and the list view
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search appointments...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() { _searchQuery = ''; });
                      },
                    )
                  : null,
            ),
            onChanged: (value) => setState(() { _searchQuery = value; }),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: appointments.length,
            itemBuilder: (context, index) {
              final appt = appointments[index];
              return Dismissible(
                key: Key(appt.id!),
                background: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: 20.0),
                      child: Icon(
                        Icons.delete,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Delete Appointment'),
                        content: Text('Are you sure you want to delete "${appt.title}"?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) async {
                  _deletedAppointment = appt;
                  _deletedIndex = index;
                  
                  await NotificationService().flutterLocalNotificationsPlugin.cancel(appt.title.hashCode ^ appt.dateTime.hashCode);
                  await healthData.deleteAppointment(appt.id!);
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Appointment "${appt.title}" deleted'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () async {
                              await healthData.addAppointment(appt);
                          },
                        ),
                      ),
                    );
                  }
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      appt.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat.yMMMd().add_jm().format(appt.dateTime),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (appt.location.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  appt.location,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (appt.notes.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.note,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  appt.notes,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          final result = await showDialog<AppointmentDialogResult>(
                            context: context,
                            builder: (context) => EditAppointmentDialog(appointment: appt),
                          );
                          if (result != null) {
                            await NotificationService().flutterLocalNotificationsPlugin.cancel(appt.title.hashCode ^ appt.dateTime.hashCode);
                            final updatedAppointment = Appointment(
                              id: appt.id,
                              title: result.title,
                              dateTime: result.dateTime,
                              location: result.location,
                              notes: result.notes,
                            );
                            await healthData.editAppointment(appt.id!, updatedAppointment);
                            final newNotifTime = result.dateTime.subtract(const Duration(hours: 1));
                            if (newNotifTime.isAfter(DateTime.now())) {
                              await NotificationService().scheduleNotification(
                                id: result.title.hashCode ^ result.dateTime.hashCode,
                                title: 'Appointment Reminder',
                                body: 'You have an appointment: ${result.title} at ${DateFormat.jm().format(result.dateTime)}',
                                scheduledTime: newNotifTime,
                              );
                            }
                          }
                        } else if (value == 'delete') {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Delete Appointment'),
                                content: Text('Are you sure you want to delete "${appt.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              );
                            },
                          );
                          
                          if (confirmed == true) {
                            await NotificationService().flutterLocalNotificationsPlugin.cancel(appt.title.hashCode ^ appt.dateTime.hashCode);
                            await healthData.deleteAppointment(appt.id!);
                          }
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
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
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No appointments yet', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first appointment',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
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
            onPressed: onClear,
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  void _showAddAppointmentDialog(BuildContext context, HealthDataProvider healthData) async {
    final result = await showDialog<AppointmentDialogResult>(
      context: context,
      builder: (context) => const AddAppointmentDialog(),
    );
    if (result != null) {
      final appt = Appointment(
        title: result.title,
        dateTime: result.dateTime,
        location: result.location,
        notes: result.notes,
      );
      await healthData.addAppointment(appt);
      // Schedule notification 1 hour before
      final notifTime = appt.dateTime.subtract(const Duration(hours: 1));
      if (notifTime.isAfter(DateTime.now())) {
        await NotificationService().scheduleNotification(
          id: appt.title.hashCode ^ appt.dateTime.hashCode,
          title: 'Appointment Reminder',
          body: 'You have an appointment: ${appt.title} at ${DateFormat.jm().format(appt.dateTime)}',
          scheduledTime: notifTime,
        );
      }
    }
  }
}

class AddAppointmentDialog extends StatefulWidget {
  const AddAppointmentDialog({Key? key}) : super(key: key);

  @override
  State<AddAppointmentDialog> createState() => _AddAppointmentDialogState();
}

class _AddAppointmentDialogState extends State<AddAppointmentDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDateTime;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Appointment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(_selectedDateTime == null
                      ? 'No date/time chosen'
                      : DateFormat.yMMMd().add_jm().format(_selectedDateTime!)),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty && _selectedDateTime != null) {
              Navigator.pop(context, AppointmentDialogResult(
                title: _titleController.text,
                location: _locationController.text,
                notes: _notesController.text,
                dateTime: _selectedDateTime!,
              ));
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class EditAppointmentDialog extends StatefulWidget {
  final Appointment appointment;
  
  const EditAppointmentDialog({Key? key, required this.appointment}) : super(key: key);

  @override
  State<EditAppointmentDialog> createState() => _EditAppointmentDialogState();
}

class _EditAppointmentDialogState extends State<EditAppointmentDialog> {
  late TextEditingController _titleController;
  late TextEditingController _locationController;
  late TextEditingController _notesController;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.appointment.title);
    _locationController = TextEditingController(text: widget.appointment.location);
    _notesController = TextEditingController(text: widget.appointment.notes);
    _selectedDateTime = widget.appointment.dateTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Appointment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(DateFormat.yMMMd().add_jm().format(_selectedDateTime)),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDateTime,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (date != null) {
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
                      );
                      if (time != null) {
                        setState(() {
                          _selectedDateTime = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          );
                        });
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty) {
              Navigator.pop(context, AppointmentDialogResult(
                title: _titleController.text,
                location: _locationController.text,
                notes: _notesController.text,
                dateTime: _selectedDateTime,
              ));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class AppointmentDialogResult {
  final String title;
  final String location;
  final String notes;
  final DateTime dateTime;

  AppointmentDialogResult({
    required this.title,
    required this.location,
    required this.notes,
    required this.dateTime,
  });
} 