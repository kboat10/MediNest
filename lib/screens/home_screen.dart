import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'schedule_screen.dart';
import 'logs_screen.dart';
import 'appointments_screen.dart';
import 'profile_screen.dart';
import '../widgets/dashboard_card.dart';
import '../providers/health_data_provider.dart';
import '../services/shared_prefs_service.dart';
import 'package:intl/intl.dart';

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
      // Modern Home Dashboard
      FutureBuilder<Map<String, String?>> (
        future: SharedPrefsService.loadUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data ?? {};
          final name = userData['name'] ?? '';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with greeting and avatar
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 36, 24, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '👋 Hello!',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name.isNotEmpty ? name : 'User',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).primaryColor.withAlpha(38),
                        child: Icon(Icons.person, size: 32, color: Theme.of(context).primaryColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Health Tips Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: HealthTipsCard(),
                ),
                const SizedBox(height: 24),
                // Upcoming Appointments
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upcoming Appointments',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Upcoming Appointment Card (dark blue)
                          Expanded(
                            child: _DarkInfoCard(
                              title: healthData.upcomingAppointments.isNotEmpty
                                ? DateFormat('dd MMM').format(healthData.upcomingAppointments[0].dateTime)
                                : '--',
                              subtitle: healthData.upcomingAppointments.isNotEmpty
                                ? healthData.upcomingAppointments[0].title
                                : 'No Appointments',
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF232A34),
                                  Color(0xFF181C1F),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Medication Streak Card (purple)
                          Expanded(
                            child: _DarkInfoCard(
                              title: '${healthData.medicationStreak} days',
                              subtitle: 'Current Streak\n(Best: ${healthData.longestStreak})',
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF7B1FA2), // purple
                                  Color(0xFF512DA8), // deep purple
                                ],
                              ),
                            ),
                          ),
                        ],
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
                

                
                const SizedBox(height: 20),
                

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
        title: const Text('MediNest'),
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


class _DarkInfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Gradient gradient;
  const _DarkInfoCard({required this.title, required this.subtitle, required this.gradient});
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
} 

class HealthTipsCard extends StatelessWidget {
  const HealthTipsCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.pushNamed(context, '/health_tips'),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 4,
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF232A34),
                Color(0xFF181C1F),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Health Tips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Get daily health tips, check drug info, and more.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 