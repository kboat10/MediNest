import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/medication.dart';
import 'dart:convert';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  // Stream for auth state changes with debug logging
  Stream<User?> get user {
    return _auth.authStateChanges().map((User? user) {
      print('AuthService - Auth state changed: ${user?.email ?? 'null'}');
      return user;
    });
  }

  // In AuthService, add a getter for the current user
  User? get currentUser {
    final user = _auth.currentUser;
    print('AuthService - Current user: ${user?.email ?? 'null'}');
    return user;
  }

  // Sign up with email and password (passcode)
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      print('AuthService - Attempting signup for: $email');
      
      // Convert 6-digit passcode to a stronger password for Firebase
      // This ensures it meets Firebase Auth requirements while keeping UI simple
      final firebasePassword = 'MediNest_${password}_${email.split('@')[0]}';
      
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: firebasePassword,
      );
      
      print('AuthService - Signup successful for: ${result.user?.email}');
      
      // DISABLED: Firestore profile creation to avoid errors
      if (result.user != null) {
        print('AuthService - User created, profile will be created during onboarding');
        
        // Set flag to indicate authentication just completed
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auth_just_completed', true);
        await prefs.setBool('is_new_signup', true); // Mark as new signup
        print('AuthService - Auth completion and new signup flags set');
      }
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('AuthService - Signup error: ${e.message}');
      return e.message; // Return the actual error message
    }
  }

  // Sign in with email and password (passcode)
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('AuthService - Attempting signin for: $email');
      
      // Convert 6-digit passcode to the same stronger password format used in signup
      final firebasePassword = 'MediNest_${password}_${email.split('@')[0]}';
      
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: firebasePassword,
      );
      print('AuthService - Signin successful for: $email');
      
      // Set flag to indicate authentication just completed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('auth_just_completed', true);
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      print('AuthService - Signin error: ${e.message}');
      return e.message; // Return the actual error message
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('AuthService - Starting sign out process...');
      
      // Clear all SharedPreferences data
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('AuthService - Cleared all SharedPreferences data');
      
      // Sign out from Firebase
      await _auth.signOut();
      print('AuthService - Sign out successful');
    } catch (e) {
      print('AuthService - Sign out error: $e');
    }
  }
} 