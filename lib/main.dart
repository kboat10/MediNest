import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/health_tips_screen.dart';
import 'services/shared_prefs_service.dart';
import 'providers/health_data_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  final bool onboarded = await SharedPrefsService.isUserOnboarded();
  runApp(
    ProviderScope(
      child: provider.MultiProvider(
        providers: [
          provider.ChangeNotifierProvider(create: (_) => HealthDataProvider()),
          provider.ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),
        ],
        child: MyApp(onboarded: onboarded),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool onboarded;
  const MyApp({Key? key, required this.onboarded}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return provider.Consumer<UserPreferencesProvider>(
      builder: (context, preferences, child) {
        return MaterialApp(
          title: 'MyMedBuddy',
          theme: preferences.getThemeData().copyWith(
            useMaterial3: true,
            cardTheme: CardThemeData(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              type: BottomNavigationBarType.fixed,
              backgroundColor: preferences.isDarkMode ? Colors.grey[900] : Colors.white,
              selectedItemColor: preferences.primaryColor,
              unselectedItemColor: Colors.grey,
              elevation: 8,
            ),
          ),
          initialRoute: onboarded ? '/home' : '/onboarding',
          routes: {
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/health_tips': (context) => const HealthTipsScreen(),
          },
        );
      },
    );
  }
}
