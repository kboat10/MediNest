import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../providers/health_data_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/loading_widget.dart';
import 'settings_screen.dart';
import 'data_management_screen.dart';
import '../services/shared_prefs_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
      ),
      body: Consumer2<HealthDataProvider, UserPreferencesProvider>(
        builder: (context, healthData, preferences, child) {
          // If Firestore profile is not available, try to load from SharedPreferences
          if (healthData.userProfile == null) {
            return FutureBuilder<Map<String, String?>>(
              future: SharedPrefsService.loadUserData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingWidget(message: 'Loading profile...');
                }
                
                if (snapshot.hasData && snapshot.data != null) {
                  final userData = snapshot.data!;
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final currentUser = authService.currentUser;
                  
                  if (currentUser != null && userData['name'] != null) {
                    // Create a temporary user profile from SharedPreferences data
                    final userProfile = UserProfile(
                      uid: currentUser.uid,
                      name: userData['name']!,
                      email: currentUser.email ?? '',
                      age: userData['age'],
                      healthCondition: userData['condition'],
                      createdAt: DateTime.now(),
                    );
                    
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHeader(
                            userProfile: userProfile,
                            onEdit: () => _showEditProfileDialog(context, userProfile),
                          ),
                          const SizedBox(height: 24),
                          _ActionCard(
                            children: [
                              _ActionTile(
                                icon: Icons.settings_outlined,
                                title: 'Settings',
                                subtitle: 'App preferences & theme',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                              ),
                              _ActionTile(
                                icon: Icons.bar_chart_outlined,
                                title: 'Data & Privacy',
                                subtitle: 'Manage your health data',
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DataManagementScreen())),
                              ),
                              _ActionTile(
                                icon: Icons.notifications_outlined,
                                title: 'Notifications',
                                subtitle: preferences.notificationsEnabled ? 'Enabled' : 'Disabled',
                                trailing: Switch(
                                  value: preferences.notificationsEnabled,
                                  onChanged: (value) => preferences.setNotificationsEnabled(value),
                                  activeColor: Theme.of(context).colorScheme.primary,
                                ),
                                onTap: () => preferences.setNotificationsEnabled(!preferences.notificationsEnabled),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.logout),
                            label: const Text('Sign Out'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade400,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _showSignOutDialog(context, authService, healthData, preferences),
                          ),
                        ],
                      ),
                    );
                  }
                }
                
                // If no data available, show error
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Unable to load profile data',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            );
          }

          final userProfile = healthData.userProfile!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(
                  userProfile: userProfile,
                  onEdit: () => _showEditProfileDialog(context, userProfile),
                ),
                const SizedBox(height: 24),
                _ActionCard(
                  children: [
                    _ActionTile(
                      icon: Icons.settings_outlined,
                      title: 'Settings',
                      subtitle: 'App preferences & theme',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
                    ),
                    _ActionTile(
                      icon: Icons.bar_chart_outlined,
                      title: 'Data & Privacy',
                      subtitle: 'Manage your health data',
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DataManagementScreen())),
                    ),
                    _ActionTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notifications',
                      subtitle: preferences.notificationsEnabled ? 'Enabled' : 'Disabled',
                      trailing: Switch(
                        value: preferences.notificationsEnabled,
                        onChanged: (value) => preferences.setNotificationsEnabled(value),
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      onTap: () => preferences.setNotificationsEnabled(!preferences.notificationsEnabled),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _showSignOutDialog(context, authService, healthData, preferences),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context, UserProfile userProfile) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: userProfile.name);
    final ageController = TextEditingController(text: userProfile.age ?? '');
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);
    final preferences = Provider.of<UserPreferencesProvider>(context, listen: false);
    String? selectedCondition = userProfile.healthCondition;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: ageController,
                  decoration: const InputDecoration(
                    labelText: 'Age',
                    prefixIcon: Icon(Icons.cake),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null || value.isEmpty) ? 'Please enter your age' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'Health Condition',
                    prefixIcon: Icon(Icons.local_hospital),
                  ),
                  items: UserPreferencesProvider.supportedConditions.map((condition) {
                    return DropdownMenuItem<String>(
                      value: condition,
                      child: Text(condition),
                    );
                  }).toList(),
                  onChanged: (val) {
                    selectedCondition = val;
                  },
                  validator: (value) => value == null ? 'Please select a health condition' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 16),
                          Text('Updating profile...'),
                        ],
                      ),
                    ),
                  );

                  final updatedProfile = userProfile.copyWith(
                    name: nameController.text,
                    age: ageController.text,
                    healthCondition: selectedCondition,
                  );
                  
                  // Update in HealthDataProvider (which handles Firestore)
                  await healthData.updateUserProfile(updatedProfile);
                  
                  // Save to SharedPreferences for immediate access
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('user_name', updatedProfile.name);
                  if (updatedProfile.age != null) {
                    await prefs.setString('user_age', updatedProfile.age!);
                  }
                  if (updatedProfile.healthCondition != null) {
                    await prefs.setString('user_condition', updatedProfile.healthCondition!);
                  }
                  
                  // Also update the preferences provider
                  if (selectedCondition != null) {
                    preferences.setHealthCondition(selectedCondition!);
                  }
                  
                  // Close loading dialog
                  Navigator.pop(context);
                  
                  // Close edit dialog
                  Navigator.pop(context);
                  
                  // Force refresh the profile screen
                  if (context.mounted) {
                    // This will trigger a rebuild with the updated data
                    healthData.notifyListeners();
                    
                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  
                } catch (e) {
                  // Close loading dialog
                  Navigator.pop(context);
                  
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update profile: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, AuthService authService, HealthDataProvider healthData, UserPreferencesProvider preferences) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Signing out will clear all your local data including medications, logs, appointments, and settings. '
          'Your data will be safely stored in the cloud and restored when you sign back in.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _signOutAndClearData(context, authService, healthData, preferences);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOutAndClearData(BuildContext context, AuthService authService, HealthDataProvider healthData, UserPreferencesProvider preferences) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Signing out...'),
            ],
          ),
        ),
      );

      // Clear all local data (same as clear all data button)
      await healthData.clearAllData();
      await preferences.clearAllPreferences();
      await SharedPrefsService.clearUserData();
      
      // Clear onboarding completion flag for this user
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboardingCompleted', false);
      await prefs.setBool('is_new_signup', false);
      
      // Clear user profile data
      await prefs.remove('user_name');
      await prefs.remove('user_age');
      await prefs.remove('user_condition');
      
      // Sign out from Firebase
      await authService.signOut();
      
      // Navigate back to AuthWrapper to let it handle the navigation logic
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: ${e.toString()}')),
        );
      }
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  final UserProfile userProfile;
  final VoidCallback onEdit;

  const _ProfileHeader({required this.userProfile, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              child: Text(
                userProfile.name.isNotEmpty ? userProfile.name[0].toUpperCase() : 'U',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              userProfile.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              userProfile.email,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            if (userProfile.age != null && userProfile.age!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cake, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Age ${userProfile.age}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            if (userProfile.healthCondition != null && 
                userProfile.healthCondition!.isNotEmpty && 
                userProfile.healthCondition != 'None') ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_hospital, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      userProfile.healthCondition!,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Profile'),
              onPressed: onEdit,
            )
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final List<Widget> children;
  const _ActionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: children,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: trailing ?? const Icon(Icons.chevron_right),
    );
  }
} 