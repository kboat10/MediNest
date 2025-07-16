import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'schedule_screen.dart';
import 'logs_screen.dart';
import 'appointments_screen.dart';
import 'profile_screen.dart';
import '../widgets/dashboard_card.dart';
import '../providers/health_data_provider.dart';
import '../services/shared_prefs_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Widget> _buildScreens(BuildContext context) {
    final healthData = Provider.of<HealthDataProvider>(context);
    final nextMed = healthData.nextMedication;
    return [
      // Enhanced Dashboard
      FutureBuilder<Map<String, String?>> (
        future: SharedPrefsService.loadUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data ?? {};
          final name = userData['name'] ?? '';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.1),
                        Theme.of(context).primaryColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 25,
                        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.health_and_safety,
                          size: 30,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? 'Welcome, $name!' : 'Welcome to MyMedBuddy',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.headlineSmall?.color,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Stay on top of your health',
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Dashboard Cards
                if (nextMed != null) ...[
                  MedicationCard(
                    medicationName: nextMed.name,
                    time: nextMed.time,
                    isNext: true,
                    onTap: () => _onItemTapped(1), // Navigate to Schedule
                  ),
                  const SizedBox(height: 16),
                ],
                
                DashboardCard(
                  title: 'Missed Doses',
                  value: '${healthData.missedDoses} this week',
                  icon: Icons.warning,
                  color: Colors.orange,
                  onTap: () => _onItemTapped(2), // Navigate to Logs
                ),
                
                DashboardCard(
                  title: 'Weekly Appointments',
                  value: '${healthData.weeklyAppointments} upcoming',
                  icon: Icons.calendar_today,
                  color: Colors.blue,
                  onTap: () => _onItemTapped(3), // Navigate to Appointments
                ),
                
                DashboardCard(
                  title: 'Health Logs',
                  value: '${healthData.logs.length} entries',
                  icon: Icons.list_alt,
                  color: Colors.green,
                  onTap: () => _onItemTapped(2), // Navigate to Logs
                ),
                
                DashboardCard(
                  title: 'Medication Streak',
                  value: '${healthData.medicationStreak} days',
                  icon: Icons.emoji_events,
                  color: Colors.purple,
                ),
                
                const SizedBox(height: 20),
                
                // Quick Actions
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.headlineSmall?.color,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(context, '/health_tips');
                  },
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.lightbulb, color: Theme.of(context).primaryColor, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Health Tips',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Get daily health tips, check drug info, and more.',
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      const ScheduleScreen(),
      const LogsScreen(),
      const AppointmentsScreen(),
      const ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('MyMedBuddy'),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 