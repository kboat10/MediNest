import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_preferences_provider.dart';
import 'settings_screen.dart';
import 'data_management_screen.dart';
import 'health_tips_screen.dart';
import '../services/shared_prefs_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
        ],
      ),
      body: FutureBuilder<Map<String, String?>> (
        future: SharedPrefsService.loadUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data ?? {};
          final name = userData['name'] ?? '';
          final age = userData['age'] ?? '';
          final condition = userData['condition'] ?? '';
          final reminders = userData['reminders'] ?? '';
          return Consumer<UserPreferencesProvider>(
            builder: (context, preferences, child) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile Header
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: preferences.primaryColor.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: preferences.primaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name.isNotEmpty ? name : 'Your Name',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              condition.isNotEmpty ? condition : 'Patient',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Remove the Quick Stats Row with Medications and Appointments
                    const SizedBox(height: 16),
                    // Profile Options
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              Icons.settings,
                              color: preferences.primaryColor,
                            ),
                            title: const Text('Settings'),
                            subtitle: const Text('Customize your app experience'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SettingsScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.storage,
                              color: preferences.primaryColor,
                            ),
                            title: const Text('Data Management'),
                            subtitle: const Text('Export, import, and backup data'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const DataManagementScreen()),
                              );
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.notifications,
                              color: preferences.primaryColor,
                            ),
                            title: const Text('Notifications'),
                            subtitle: Text(
                              preferences.notificationsEnabled ? 'Enabled' : 'Disabled',
                            ),
                            trailing: Switch(
                              value: preferences.notificationsEnabled,
                              onChanged: (value) => preferences.setNotificationsEnabled(value),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              preferences.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                              color: preferences.primaryColor,
                            ),
                            title: const Text('Dark Mode'),
                            subtitle: const Text('Toggle dark theme'),
                            trailing: Switch(
                              value: preferences.isDarkMode,
                              onChanged: (value) => preferences.setDarkMode(value),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Health Information
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Health Information',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.cake,
                              color: Colors.purple,
                            ),
                            title: const Text('Age'),
                            subtitle: Text(age.isNotEmpty ? age : 'Not set'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.local_hospital,
                              color: Colors.green,
                            ),
                            title: const Text('Condition'),
                            subtitle: Text(condition.isNotEmpty ? condition : 'Not set'),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.alarm,
                              color: Colors.blue,
                            ),
                            title: const Text('Medication Reminders'),
                            subtitle: Text(reminders.isNotEmpty ? reminders : 'Not set'),
                          ),
                        ],
                      ),
                    ),
                    // Emergency Contacts
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Emergency Contacts',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: preferences.primaryColor.withOpacity(0.2),
                              child: Icon(
                                Icons.person,
                                color: preferences.primaryColor,
                              ),
                            ),
                            title: const Text('Jane Doe'),
                            subtitle: const Text('Spouse • (555) 123-4567'),
                            trailing: IconButton(
                              icon: const Icon(Icons.phone),
                              onPressed: () {
                                // TODO: Implement phone call
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Calling Jane Doe...')),
                                );
                              },
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.green.withOpacity(0.2),
                              child: const Icon(
                                Icons.local_hospital,
                                color: Colors.green,
                              ),
                            ),
                            title: const Text('Dr. Smith'),
                            subtitle: const Text('Primary Care • (555) 987-6543'),
                            trailing: IconButton(
                              icon: const Icon(Icons.phone),
                              onPressed: () {
                                // TODO: Implement phone call
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Calling Dr. Smith...')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: color,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
} 