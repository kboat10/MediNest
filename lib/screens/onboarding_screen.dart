import 'package:flutter/material.dart';
import '../services/shared_prefs_service.dart';
import 'package:provider/provider.dart';
import '../providers/health_data_provider.dart';
import '../models/medication.dart';
import '../providers/user_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // Added for jsonEncode
import 'dart:async'; // Added for TimeoutException
import '../services/auth_service.dart'; // Added for AuthService
import '../models/user_profile.dart'; // Added for UserProfile
import '../screens/home_screen.dart'; // Added for HomeScreen
import '../services/firestore_service.dart'; // Added for FirestoreService

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final List<Map<String, dynamic>> _medReminders = [
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
    for (var item in _medReminders) {
      item['name'].dispose();
    }
    super.dispose();
  }

  void _submitForm() async {
    print('Onboarding - Submit form button pressed');
    if (_formKey.currentState!.validate()) {
      print('Onboarding - Form validation passed, starting submission');
      
      try {
        // Save basic user data
        print('Onboarding - About to save user data to SharedPreferences');
        await SharedPrefsService.saveUserData(
          name: _nameController.text,
          age: _ageController.text,
          condition: _selectedCondition ?? 'None',
          reminders: _medReminders.map((e) => '${e['name'].text} at ${e['time']}').join(', '),
        );
        print('Onboarding - Successfully saved user data to SharedPreferences');
        
        // Also save to the keys that HealthDataProvider expects
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', _nameController.text);
        await prefs.setString('user_age', _ageController.text);
        if (_selectedCondition != null) {
          await prefs.setString('user_condition', _selectedCondition!);
        }
        print('Onboarding - Saved user data to HealthDataProvider keys');
        
        // Store medications temporarily in SharedPreferences to be transferred after authentication
        print('Onboarding - About to save medications to SharedPreferences');
        final medicationData = _medReminders
            .where((item) => item['name'].text.isNotEmpty && item['time'] != null)
            .map((item) => {
              'name': item['name'].text,
              'time': item['time'],
              'reminderTime': item['time'],
            })
            .toList();
        
        if (medicationData.isNotEmpty) {
          await prefs.setString('onboarding_medications', jsonEncode(medicationData));
          print('Onboarding - Saved ${medicationData.length} medications to SharedPreferences');
        }
        
        // Save health condition to preferences
        print('Onboarding - About to save health condition to preferences');
        final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
        if (_selectedCondition != null) {
          await preferences.setHealthCondition(_selectedCondition!);
          print('Onboarding - Successfully saved health condition');
        }
        
        // Update user profile in Firestore with onboarding data
        print('Onboarding - About to update user profile in Firestore');
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        print('Onboarding - Current user: ${currentUser?.email}');
        
        // HYBRID APPROACH: Save to SharedPreferences first, then attempt Firestore sync
        if (currentUser != null) {
          try {
            final userProfile = UserProfile(
              uid: currentUser.uid,
              name: _nameController.text,
              email: currentUser.email ?? '',
              age: _ageController.text,
              healthCondition: _selectedCondition,
              createdAt: DateTime.now(),
            );
            
            // Save medications to SharedPreferences for immediate use
            print('Onboarding - Saving medications to SharedPreferences for immediate use');
            final prefs = await SharedPreferences.getInstance();
            if (medicationData.isNotEmpty) {
              await prefs.setString('medications', jsonEncode(medicationData));
              print('Onboarding - Successfully saved ${medicationData.length} medications to SharedPreferences');
            }
            
                    // DISABLED: Firestore sync to avoid errors
        print('Onboarding - Firestore sync disabled, using SharedPreferences only');
            
          } catch (e) {
            print('Onboarding - Error in profile creation: $e');
            // Continue with navigation even if profile creation fails
          }
        }
        
        // Mark onboarding as completed and navigate to home
        print('Onboarding - About to mark onboarding as completed');
        await prefs.setBool('onboardingCompleted', true);
        print('Onboarding - Marked as completed, navigating to home');
        
        // Force a small delay to ensure all state updates are processed
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        // Force navigation to home screen
        print('Onboarding - Starting navigation to home screen');
        try {
          Navigator.of(context).pushReplacementNamed('/home');
          print('Onboarding - Navigation to home screen completed');
        } catch (e) {
          print('Onboarding - Error with named route navigation: $e');
          // Fallback: navigate directly to HomeScreen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
          print('Onboarding - Fallback navigation to home screen completed');
        }
      } catch (e) {
        print('Onboarding - Error in _submitForm: $e');
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
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
                                  prefixIcon: Icon(Icons.local_hospital),
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
                                validator: (value) => value == null || value.isEmpty ? 'Please select your health condition' : null,
                              ),
                            );
                          },
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