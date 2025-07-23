import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/health_data_provider.dart';
import '../providers/user_preferences_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passcodeController = TextEditingController();
  String _email = '';
  String _passcode = '';
  bool _isLogin = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Reset loading state when screen is initialized
    _isLoading = false;
    _error = null;
    print('AuthScreen - Initialized with loading state: $_isLoading');
    
    // Check if user is already authenticated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        print('AuthScreen - User already authenticated: ${currentUser.email}');
        // User is already logged in, let AuthWrapper handle navigation
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passcodeController.dispose();
    // Reset loading state when screen is disposed
    _isLoading = false;
    print('AuthScreen - Disposed, loading state reset to: $_isLoading');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure loading state is properly reset if somehow stuck
    if (_isLoading && _error == null) {
      print('AuthScreen - Detected stuck loading state, resetting');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    }
    
    // Force reset loading state on every build to prevent persistence
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isLoading && _error == null) {
        print('AuthScreen - Force resetting loading state on build');
        setState(() {
          _isLoading = false;
        });
      }
    });
    
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(_isLogin ? 'Sign In' : 'Sign Up'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Icon and Title
              Icon(
                Icons.health_and_safety,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                'MediNest',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin ? 'Welcome back!' : 'Create your account',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              
              // Form Card
              Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!val.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            setState(() {
                              _email = val;
                              _error = null; // Clear error when user types
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passcodeController,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: '6-Digit Passcode',
                            prefixIcon: const Icon(Icons.lock),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            counterText: '${_passcode.length}/6',
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          maxLength: 6,
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter a passcode';
                            }
                            if (val.length < 6) {
                              return 'Passcode must be 6 digits';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            setState(() {
                              _passcode = val;
                              _error = null; // Clear error when user types
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Error Message
                        if (_error != null && _error!.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _getErrorMessage(_error!),
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        
                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Builder(
                              builder: (context) {
                                print('AuthScreen - Button loading state: $_isLoading');
                                if (_isLoading) {
                                  print('AuthScreen - Button showing loading spinner');
                                } else {
                                  print('AuthScreen - Button showing text: ${_isLogin ? 'Sign In' : 'Sign Up'}');
                                }
                                return _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        _isLogin ? 'Sign In' : 'Sign Up',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Toggle Login/Signup
              TextButton(
                onPressed: _isLoading ? null : () {
                  setState(() {
                    _isLogin = !_isLogin;
                    _error = null;
                    _emailController.clear();
                    _passcodeController.clear();
                    _email = '';
                    _passcode = '';
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: _isLogin
                            ? "Don't have an account? "
                            : "Already have an account? ",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      TextSpan(
                        text: _isLogin ? 'Sign Up' : 'Sign In',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    print('AuthScreen - Starting ${_isLogin ? 'signin' : 'signup'} for: $_email');
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      String? error;
      
      if (_isLogin) {
        error = await authService.signInWithEmailAndPassword(_email, _passcode);
      } else {
        error = await authService.signUpWithEmailAndPassword(_email, _passcode);
      }
      
      print('AuthScreen - Auth result: ${error ?? 'SUCCESS'}');
      
      if (error != null) {
        if (mounted) {
          setState(() {
            _error = error;
            _isLoading = false;
          });
        }
      } else {
        print('AuthScreen - Auth successful, clearing loading state');
        
        // Clear loading state and let AuthWrapper handle navigation
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Check if user is authenticated immediately
          final currentUser = FirebaseAuth.instance.currentUser;
          print('AuthScreen - Current user after auth: ${currentUser?.email}');
          
          // Add a small delay to ensure AuthWrapper detects the auth state change
          await Future.delayed(const Duration(milliseconds: 100));
          print('AuthScreen - Delay completed, AuthWrapper should have detected auth state change');
        }
        // AuthWrapper will automatically detect the auth state change and navigate
      }
    } catch (e) {
      print('AuthScreen - Auth exception: $e');
      if (mounted) {
        setState(() {
          _error = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  String _getErrorMessage(String firebaseError) {
    // Convert Firebase error messages to user-friendly messages
    if (firebaseError.contains('email-already-in-use')) {
      return 'This email is already registered. Try signing in instead.';
    } else if (firebaseError.contains('weak-password')) {
      return 'Please choose a stronger passcode.';
    } else if (firebaseError.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (firebaseError.contains('user-not-found')) {
      return 'No account found with this email. Try signing up instead.';
    } else if (firebaseError.contains('wrong-password')) {
      return 'Incorrect passcode. Please try again.';
    } else if (firebaseError.contains('too-many-requests')) {
      return 'Too many failed attempts. Please try again later.';
    } else if (firebaseError.contains('network-request-failed')) {
      return 'Network error. Please check your connection and try again.';
    }
    return firebaseError; // Return original message if no specific match
  }
} 