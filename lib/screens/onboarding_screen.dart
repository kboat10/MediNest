import 'package:flutter/material.dart';
import '../services/shared_prefs_service.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/medication.dart';
import '../providers/user_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _conditionController = TextEditingController();
  List<Map<String, dynamic>> _medReminders = [
    {'name': TextEditingController(), 'time': null},
  ];
  String? _selectedCondition;

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
    _nameController.dispose();
    _ageController.dispose();
    _conditionController.dispose();
    for (var item in _medReminders) {
      item['name'].dispose();
    }
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      await SharedPrefsService.saveUserData(
        name: _nameController.text,
        age: _ageController.text,
        condition: _conditionController.text,
        reminders: _medReminders.map((e) => '${e['name'].text} at ${e['time']}').join(', '),
      );
      // Add medications to schedule
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      for (var item in _medReminders) {
        if (item['name'].text.isNotEmpty && item['time'] != null) {
          await healthData.addMedication(Medication(
            name: item['name'].text,
            time: item['time'],
            reminderTime: item['time'],
          ));
        }
      }
      final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
      if (_selectedCondition != null) {
        await preferences.setHealthCondition(_selectedCondition!);
      }
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboardingCompleted', true);
      Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon and Welcome
              Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.primaryColor.withAlpha(51),
                    child: Icon(Icons.health_and_safety, size: 48, color: theme.primaryColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to MediNest',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let’s get to know you!',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _ageController,
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            prefixIcon: Icon(Icons.cake),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) => value == null || value.isEmpty ? 'Enter your age' : null,
                        ),
                        const SizedBox(height: 16),
                        Consumer<UserPreferencesProvider>(
                          builder: (context, preferences, _) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCondition,
                                decoration: const InputDecoration(
                                  labelText: 'Select your primary health condition',
                                  border: OutlineInputBorder(),
                                ),
                                items: UserPreferencesProvider.supportedConditions.map((condition) {
                                  return DropdownMenuItem<String>(
                                    value: condition,
                                    child: Text(condition),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedCondition = val;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                        TextFormField(
                          controller: _conditionController,
                          decoration: const InputDecoration(
                            labelText: 'Condition',
                            prefixIcon: Icon(Icons.local_hospital),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Enter your condition' : null,
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Medication Reminders', style: theme.textTheme.titleMedium),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          children: [
                            for (int i = 0; i < _medReminders.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    TextFormField(
                                      controller: _medReminders[i]['name'],
                                      decoration: const InputDecoration(
                                        labelText: 'Medication Name',
                                        prefixIcon: Icon(Icons.medication),
                                      ),
                                      validator: (value) => value == null || value.isEmpty ? 'Enter medication name' : null,
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      value: _medReminders[i]['time'],
                                      items: getTimeOptions().map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (val) => setState(() => _medReminders[i]['time'] = val),
                                      decoration: const InputDecoration(
                                        labelText: 'Time',
                                        prefixIcon: Icon(Icons.access_time),
                                      ),
                                      validator: (value) => value == null || value.isEmpty ? 'Select time' : null,
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: _medReminders.length > 1
                                            ? () => setState(() => _medReminders.removeAt(i))
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text('Add Another'),
                                onPressed: () => setState(() => _medReminders.add({'name': TextEditingController(), 'time': null})),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.arrow_forward),
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            label: const Text('Get Started'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 