import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../providers/health_data_provider.dart';
import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _onboardingCompleted = false;
  bool _hasReceivedInitialData = false; // Track if we've received initial auth state
  bool _authJustCompleted = false; // Track if auth just completed
  bool _isLoadingLocalData = false; // Track if we're loading local data
  bool _isNewSignup = false; // Track if this is a new signup
  User? _previousUser; // Track previous user to detect sign out

  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    
    final onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;
    final authJustCompleted = prefs.getBool('auth_just_completed') ?? false;
    final isNewSignup = prefs.getBool('is_new_signup') ?? false;
    
    print('AuthWrapper - _checkOnboardingStatus:');
    print('  - onboardingCompleted from SharedPreferences: $onboardingCompleted');
    print('  - auth_just_completed from SharedPreferences: $authJustCompleted');
    print('  - is_new_signup from SharedPreferences: $isNewSignup');
    
    setState(() {
      _onboardingCompleted = onboardingCompleted;
      _authJustCompleted = authJustCompleted;
      _isNewSignup = isNewSignup;
    });
    
    // Clear the auth completion flag after reading it
    if (_authJustCompleted) {
      await prefs.setBool('auth_just_completed', false);
      print('AuthWrapper - Cleared auth_just_completed flag');
    }
    
    // Clear the new signup flag after reading it
    if (_isNewSignup) {
      await prefs.setBool('is_new_signup', false);
      print('AuthWrapper - Cleared is_new_signup flag');
    }
    
    print('AuthWrapper - Final state after _checkOnboardingStatus:');
    print('  - _onboardingCompleted: $_onboardingCompleted');
    print('  - _authJustCompleted: $_authJustCompleted');
    print('  - _isNewSignup: $_isNewSignup');
  }
  
  // Method to reload onboarding status from SharedPreferences
  Future<void> _reloadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboardingCompleted') ?? false;
    
    print('AuthWrapper - _reloadOnboardingStatus:');
    print('  - onboardingCompleted from SharedPreferences: $onboardingCompleted');
    
    setState(() {
      _onboardingCompleted = onboardingCompleted;
    });
    
    print('AuthWrapper - Updated _onboardingCompleted: $_onboardingCompleted');
  }

  // Method to ensure local data is ready before showing screens
  Future<void> _ensureLocalDataReady(BuildContext context) async {
    if (_isLoadingLocalData) return;
    
    setState(() {
      _isLoadingLocalData = true;
    });
    
    try {
      final healthData = Provider.of<HealthDataProvider>(context, listen: false);
      await healthData.ensureLocalDataReady();
      print('AuthWrapper - Local data is ready');
    } catch (e) {
      print('AuthWrapper - Error ensuring local data ready: $e');
    } finally {
      setState(() {
        _isLoadingLocalData = false;
      });
    }
  }

  // Method to force refresh auth state
  void _forceRefresh() {
    print('AuthWrapper - Force refreshing auth state');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final healthData = Provider.of<HealthDataProvider>(context, listen: false);
    
    // Check Firebase Auth current user directly as a fallback
    final currentUser = FirebaseAuth.instance.currentUser;

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        print('AuthWrapper - Connection state: ${snapshot.connectionState}');
        print('AuthWrapper - Has user: ${snapshot.hasData}');
        print('AuthWrapper - User: ${snapshot.data?.email}');
        print('AuthWrapper - Current user direct: ${currentUser?.email}');
        print('AuthWrapper - Onboarding completed: $_onboardingCompleted');
        print('AuthWrapper - Has received initial data: $_hasReceivedInitialData');
        print('AuthWrapper - Auth just completed: $_authJustCompleted');

        // Update previous user - but only if we actually have a user
        // This prevents false sign-out detection on app restart
        if (snapshot.data != null || currentUser != null) {
          _previousUser = snapshot.data ?? currentUser;
        }
        
        // Detect sign out (user was signed in but now is not)
        // Only clear data if we had a previous user and now we don't have any user
        // AND we're not in the initial loading state
        if (_previousUser != null && 
            snapshot.data == null && 
            currentUser == null && 
            snapshot.connectionState != ConnectionState.waiting &&
            _hasReceivedInitialData) {
          print('AuthWrapper - User signed out detected, clearing data...');
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await healthData.clearAllUserData();
            setState(() {
              _onboardingCompleted = false;
              _hasReceivedInitialData = false;
              _authJustCompleted = false;
              _isLoadingLocalData = false;
              _isNewSignup = false;
              _previousUser = null;
            });
          });
        }

        // Only show loading screen on the very first connection AND only if we haven't received any data yet
        // AND we don't have a current user AND auth didn't just complete
        if (snapshot.connectionState == ConnectionState.waiting && 
            !_hasReceivedInitialData && 
            !snapshot.hasData &&
            currentUser == null &&
            !_authJustCompleted) {
          print('AuthWrapper - Showing loading screen');
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Mark that we've received initial data once we have any connection state that's not waiting
        // OR if we actually have data
        if (!_hasReceivedInitialData && 
            (snapshot.connectionState != ConnectionState.waiting || snapshot.hasData || currentUser != null || _authJustCompleted)) {
          print('AuthWrapper - Marking initial data as received');
          _hasReceivedInitialData = true;
        }

        if (snapshot.hasData || currentUser != null || _authJustCompleted) {
          // User is authenticated - ensure local data is ready and check if they need onboarding
          print('AuthWrapper - User authenticated, ensuring local data ready');
          
          // Ensure local data is ready before showing screens
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureLocalDataReady(context);
          });
          
          // Reload onboarding status to ensure it's current
          if (!_isNewSignup && !_onboardingCompleted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _reloadOnboardingStatus();
            });
          }
          
          // New signup always goes to onboarding
          if (_isNewSignup) {
            print('AuthWrapper - New signup detected, going to OnboardingScreen');
            return const OnboardingScreen();
          }
          
          // Existing user: check if onboarding completed
          if (_onboardingCompleted) {
            print('AuthWrapper - Onboarding completed, going to HomeScreen');
            return const HomeScreen();
          } else {
            print('AuthWrapper - Onboarding not completed, going to OnboardingScreen');
            return const OnboardingScreen();
          }
        } else {
          // User is not authenticated - show auth screen
          print('AuthWrapper - User not authenticated, going to AuthScreen');
          return const AuthScreen();
        }
      },
    );
  }
} 