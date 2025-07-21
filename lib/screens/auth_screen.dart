import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'package:flutter/services.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _passcode = '';
  bool _isLogin = true;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Login' : 'Sign Up'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (val) => val!.isEmpty ? 'Enter an email' : null,
                onChanged: (val) {
                  setState(() => _email = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '6-Digit Passcode'),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                validator: (val) => val!.length < 6 ? 'Enter a 6-digit passcode' : null,
                onChanged: (val) {
                  setState(() => _passcode = val);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: Text(_isLogin ? 'Login' : 'Sign Up'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    String? error;
                    if (_isLogin) {
                      error = await authService.signInWithEmailAndPassword(_email, _passcode);
                    } else {
                      error = await authService.signUpWithEmailAndPassword(_email, _passcode);
                    }
                    if (error != null) {
                      setState(() => _error = error);
                    }
                  }
                },
              ),
              TextButton(
                child: Text(_isLogin ? 'Create an account' : 'I already have an account'),
                onPressed: () {
                  setState(() => _isLogin = !_isLogin);
                },
              ),
              if (_error != null && _error!.isNotEmpty)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 