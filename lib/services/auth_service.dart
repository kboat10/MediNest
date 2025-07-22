import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  // Stream for auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // In AuthService, add a getter for the current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password (passcode)
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      
      // Create user profile document in Firestore
      if (result.user != null) {
        // Try to get the name from onboarding data
        final prefs = await SharedPreferences.getInstance();
        final onboardingName = prefs.getString('user_name') ?? '';
        
        final userProfile = UserProfile(
          uid: result.user!.uid,
          name: onboardingName.isNotEmpty ? onboardingName : (result.user!.displayName ?? ''),
          email: result.user!.email ?? email.trim(),
        );
        await _firestore.setUserProfile(userProfile);
      }
      
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return the actual error message
    }
  }

  // Sign in with email and password (passcode)
  Future<String?> signInWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return e.message; // Return the actual error message
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
} 