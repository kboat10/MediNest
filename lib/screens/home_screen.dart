import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'schedule_screen.dart';
import 'logs_screen.dart';
import 'appointments_screen.dart';
import 'profile_screen.dart';
import '../widgets/dashboard_card.dart';
import '../providers/health_data_provider.dart';
import '../services/shared_prefs_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _userName = 'User';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize services for HealthDataProvider
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);
    final authService = Provider.of<AuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    // Initialize services if not already done
    healthData.initializeServices(authService, firestoreService);
    
    // Force load user profile if not available
    if (healthData.userProfile == null) {
      print('HomeScreen - User profile is null, forcing load...');
      healthData.loadUserProfileFromSharedPreferences().then((_) {
        print('HomeScreen - User profile loaded: ${healthData.userProfile?.name}');
        if (healthData.userProfile?.name != null && healthData.userProfile!.name.isNotEmpty) {
          setState(() {
            _userName = healthData.userProfile!.name;
          });
        }
      });
    }
    
    // Listen to HealthDataProvider changes
    if (healthData.userProfile?.name != null && 
        healthData.userProfile!.name.isNotEmpty && 
        healthData.userProfile!.name != _userName) {
      setState(() {
        _userName = healthData.userProfile!.name;
      });
    }
  }



  Future<void> _loadUserName() async {
    try {
      print('HomeScreen - Loading user name from SharedPrefsService...');
      final userData = await SharedPrefsService.loadUserData();
      print('HomeScreen - User data loaded: $userData');
      if (userData['name'] != null && userData['name']!.isNotEmpty) {
        setState(() {
          _userName = userData['name']!;
        });
        print('HomeScreen - User name set to: $_userName');
      } else {
        print('HomeScreen - No user name found in SharedPrefsService');
      }
    } catch (e) {
      print('HomeScreen - Error loading user name: $e');
    }
  }

  List<Widget> _buildScreens(BuildContext context) {
    final healthData = Provider.of<HealthDataProvider>(context);
    final nextMed = healthData.nextMedication;
    return [
      // Modern Home Dashboard
      Consumer<HealthDataProvider>(
        builder: (context, healthData, child) {
          final userProfile = healthData.userProfile;
          print('HomeScreen - User profile: ${userProfile?.name ?? 'null'}');
          print('HomeScreen - Cached user name: $_userName');
          
          // Use profile name if available, otherwise use cached name, otherwise use 'User'
          String name = userProfile?.name ?? _userName;
          if (name.isEmpty) {
            name = 'User';
          }
          print('HomeScreen - Final name to display: $name');
          
          // Update cached name if profile has a different name
          if (userProfile?.name != null && userProfile!.name.isNotEmpty && name != _userName) {
            _userName = name;
            print('HomeScreen - Updated cached name to: $_userName');
          }
          
          return _buildHomeContent(context, healthData, name);
        },
      ),
      const ScheduleScreen(),
      const LogsScreen(),
      const AppointmentsScreen(),
      const ProfileScreen(),
    ];
  }

  Widget _buildHomeContent(BuildContext context, HealthDataProvider healthData, String name) {
    final nextMed = healthData.nextMedication;
    
    // Get the current time for greeting
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = '🌅 Good Morning!';
    } else if (hour < 17) {
      greeting = '☀️ Good Afternoon!';
    } else {
      greeting = '🌙 Good Evening!';
    }
    
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
                        greeting,
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
                  child: name.isNotEmpty 
                      ? Text(
                          name[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : Icon(
                          Icons.person,
                          size: 24,
                          color: Theme.of(context).primaryColor,
                        ),
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
  const HealthTipsCard({super.key});

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