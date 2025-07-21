import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MediNest',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 2,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: Consumer<UserPreferencesProvider>(
        builder: (context, preferences, child) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // Dark Mode Toggle
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Use dark theme'),
                      secondary: Icon(
                        preferences.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      value: preferences.isDarkMode,
                      onChanged: (value) => preferences.setDarkMode(value),
                    ),
                    const Divider(height: 1),
                    
                    // Font Size
                    ListTile(
                      title: const Text('Font Size'),
                      subtitle: Text('${(preferences.fontSize * 100).round()}%'),
                      leading: Icon(
                        Icons.text_fields,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showFontSizeDialog(context, preferences),
                    ),
                  ],
                ),
              ),
              
              // Theme Colors Section
              _buildSectionHeader(context, 'Theme Colors'),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // Primary Color
                    ListTile(
                      title: const Text('Primary Color'),
                      subtitle: const Text('Main app color'),
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: preferences.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showColorPickerDialog(context, preferences, true),
                    ),
                    const Divider(height: 1),
                    
                    // Accent Color
                    ListTile(
                      title: const Text('Accent Color'),
                      subtitle: const Text('Secondary app color'),
                      leading: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: preferences.accentColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey),
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showColorPickerDialog(context, preferences, false),
                    ),
                  ],
                ),
              ),
              
              // Notifications Section
              _buildSectionHeader(context, 'Notifications'),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    // General Notifications
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text('Receive app notifications'),
                      secondary: Icon(
                        Icons.notifications,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      value: preferences.notificationsEnabled,
                      onChanged: (value) => preferences.setNotificationsEnabled(value),
                    ),
                    const Divider(height: 1),
                    
                    // Medication Reminders
                    SwitchListTile(
                      title: const Text('Medication Reminders'),
                      subtitle: const Text('Remind me to take medications'),
                      secondary: Icon(
                        Icons.medication,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      value: preferences.medicationReminders && preferences.notificationsEnabled,
                      onChanged: preferences.notificationsEnabled
                          ? (value) => preferences.setMedicationReminders(value)
                          : null,
                    ),
                    const Divider(height: 1),
                    
                    // Appointment Reminders
                    SwitchListTile(
                      title: const Text('Appointment Reminders'),
                      subtitle: const Text('Remind me about appointments'),
                      secondary: Icon(
                        Icons.calendar_today,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      value: preferences.appointmentReminders && preferences.notificationsEnabled,
                      onChanged: preferences.notificationsEnabled
                          ? (value) => preferences.setAppointmentReminders(value)
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Test Notification'),
                        onPressed: () {
                          NotificationService().showNotification(
                            id: 0,
                            title: 'Test Notification',
                            body: 'This is a test notification from MediNest.',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              // About Section
              _buildSectionHeader(context, 'About'),
              Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text('App Version'),
                      subtitle: const Text('1.0.0'),
                      leading: Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Privacy Policy'),
                      leading: Icon(
                        Icons.privacy_tip_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Navigate to privacy policy
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Privacy Policy coming soon')),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      title: const Text('Terms of Service'),
                      leading: Icon(
                        Icons.description_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Navigate to terms of service
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Terms of Service coming soon')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                child: DropdownButtonFormField<String>(
                  value: preferences.healthCondition.isNotEmpty ? preferences.healthCondition : null,
                  decoration: const InputDecoration(
                    labelText: 'Health Condition',
                    border: OutlineInputBorder(),
                  ),
                  items: UserPreferencesProvider.supportedConditions.map((condition) {
                    return DropdownMenuItem<String>(
                      value: condition,
                      child: Text(condition),
                    );
                  }).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      await preferences.setHealthCondition(val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Health condition updated to $val.')),
                      );
                    }
                  },
                ),
              ),
            ],
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
  
  void _showFontSizeDialog(BuildContext context, UserPreferencesProvider preferences) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Font Size'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserPreferencesProvider.fontSizeOptions.map((size) {
            return RadioListTile<double>(
              title: Text(
                'Sample Text',
                style: TextStyle(fontSize: 16 * size),
              ),
              subtitle: Text('${(size * 100).round()}%'),
              value: size,
              groupValue: preferences.fontSize,
              onChanged: (value) {
                if (value != null) {
                  preferences.setFontSize(value);
                  Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _showColorPickerDialog(BuildContext context, UserPreferencesProvider preferences, bool isPrimary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isPrimary ? 'Primary Color' : 'Accent Color'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: UserPreferencesProvider.availableColors.length,
            itemBuilder: (context, index) {
              final color = UserPreferencesProvider.availableColors[index];
              final isSelected = isPrimary 
                  ? preferences.primaryColor == color
                  : preferences.accentColor == color;
              
              return GestureDetector(
                onTap: () {
                  if (isPrimary) {
                    preferences.setPrimaryColor(color);
                  } else {
                    preferences.setAccentColor(color);
                  }
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.grey,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
} 