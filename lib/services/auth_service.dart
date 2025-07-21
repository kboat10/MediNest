import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream for auth state changes
  Stream<User?> get user => _auth.authStateChanges();

  // In AuthService, add a getter for the current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password (passcode)
  Future<String?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
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