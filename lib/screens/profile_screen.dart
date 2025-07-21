import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../providers/health_data_provider.dart';
import '../providers/user_preferences_provider.dart';
import '../widgets/loading_widget.dart';
import 'settings_screen.dart';
import 'data_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
          if (healthData.userProfile == null) {
            return const LoadingWidget(message: 'Loading profile...');
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
                  onPressed: () async {
                    await authService.signOut();
                    Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                  },
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
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
            validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final updatedProfile = UserProfile(
                  uid: userProfile.uid,
                  name: nameController.text,
                  email: userProfile.email,
                );
                healthData.updateUserProfile(updatedProfile);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully!')),
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