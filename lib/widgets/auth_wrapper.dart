import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth_screen.dart'; // We will create this next
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../providers/health_data_provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _onboardingCompleted = false;

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          // User is logged in
          return const HomeScreen();
        } else {
          // User is not logged in
          if (_onboardingCompleted) {
            return const AuthScreen();
          } else {
            return const OnboardingScreen();
          }
        }
      },
    );
  }
} 