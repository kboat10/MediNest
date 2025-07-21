import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Remove the conflicting flutter_riverpod import
// import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/health_tips_screen.dart';
import 'screens/auth_screen.dart';
import 'services/shared_prefs_service.dart';
import 'providers/health_data_provider.dart';
import 'providers/user_preferences_provider.dart';
import 'services/notification_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import './services/auth_service.dart';
import './widgets/auth_wrapper.dart';
import './services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Enable Firestore offline persistence
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);
  await NotificationService().init();
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  runApp(
    MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => UserPreferencesProvider()),
        // This provider depends on AuthService and FirestoreService
        ChangeNotifierProxyProvider2<AuthService, FirestoreService, HealthDataProvider>(
          create: (context) => HealthDataProvider(),
          update: (context, auth, firestore, previousHealthData) =>
              previousHealthData!..update(auth, firestore),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UserPreferencesProvider>(
      builder: (context, preferences, child) {
        return MaterialApp(
          title: 'MediNest',
          theme: preferences.getThemeData(),
          home: const AuthWrapper(),
          routes: {
            '/auth': (context) => const AuthScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/home': (context) => const HomeScreen(),
            '/health_tips': (context) => const HealthTipsScreen(),
          },
        );
      },
    );
  }
}
