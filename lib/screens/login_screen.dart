import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _email, _password, _error;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() {
      _loading = true;
      _error = null;
    });

    final resp = await http.post(
      Uri.parse('http://localhost:8080/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': _email, 'password': _password}),
    );
    final data = json.decode(resp.body);
    if (resp.statusCode == 200 && data['access_token'] != null) {
      // Store the token using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', data['access_token']);
      // Redirect to home page
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() {
        _error = data['message'] ?? 'Login failed';
      });
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      body: Stack(fit: StackFit.expand, children: [
        // 1) Background image + dark overlay
        Image.asset('assets/images/bg_screen.png', fit: BoxFit.cover),
        Container(color: Colors.black45),

        // 2) Centered login card
        Center(
          child: Card(
            elevation: 8,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // logo
                Image.asset(
                  'assets/images/logo_meal_planner.png',
                  width: 64,
                  height: 64,
                ),
                const SizedBox(height: 16),

                // title
                const Text(
                  'Sign In',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // error
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                if (_error != null) const SizedBox(height: 12),

                // form
                Form(
                  key: _formKey,
                  child: Column(children: [
                    TextFormField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.email),
                        labelText: 'Email',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v != null && v.contains('@') ? null : 'Invalid email',
                      onSaved: (v) => _email = v,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        labelText: 'Password',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none),
                      ),
                      obscureText: true,
                      validator: (v) => v != null && v.length >= 8
                          ? null
                          : 'Min 8 characters',
                      onSaved: (v) => _password = v,
                    ),
                    const SizedBox(height: 24),

                    // sign in button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Sign In'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // goto signup
                    TextButton(
                      onPressed: () => Navigator.pushNamed(ctx, '/signup'),
                      child: const Text(
                        "Don't have an account? Sign up",
                        style: TextStyle(decoration: TextDecoration.underline),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}