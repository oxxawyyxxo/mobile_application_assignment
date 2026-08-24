import 'package:flutter/material.dart';
import '../main.dart';
import '../menus/customer_menu.dart';
import '../menus/staff_menu.dart';
import 'register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  String _selectedRole = "User";
  bool _isLoading = false; // Added to handle loading state

  // Changed to email controller because Supabase requires emails
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;

      try {
        // 1. Authenticate with Supabase
        final response = await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );

        final user = response.user;
        if (user != null) {
          // 2. Fetch the role and full name from the user_profiles table
          final profileData = await _supabase
              .from('user_profiles')
              .select('role, full_name')
              .eq('id', user.id)
              .maybeSingle();

          if (profileData == null) {
            await _supabase.auth.signOut();
            _showErrorDialog('User profile not found in database.');
            setState(() => _isLoading = false);
            return;
          }

          final String userRole = profileData['role'] ?? 'User';
          final String fullName = profileData['full_name'] ?? 'Unknown';

          // 3. Verify they selected the correct role (case-insensitive)
          if (userRole.toLowerCase() != _selectedRole.toLowerCase()) {
            await _supabase.auth.signOut(); // Log out immediately if wrong role
            _showErrorDialog('Incorrect role selected for this account.');
            setState(() => _isLoading = false);
            return;
          }

          // 4. Navigate to correct menu
          if (!mounted) return;
          if (userRole.toLowerCase() == 'staff') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => StaffMenu(name: fullName),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CustomerMenu(name: fullName),
              ),
            );
          }
        }
      } on AuthException catch (e) {
        // Show Supabase specific errors (e.g., Invalid login credentials)
        _showErrorDialog(e.message);
      } catch (e) {
        _showErrorDialog('An unexpected error occurred: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Helper method to keep your original error dialog style clean
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void swipe() {
    setState(() {
      if (_selectedRole == 'User') {
        _selectedRole = 'Staff';
        return;
      }
      _selectedRole = 'User';
      return;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Screen'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    color: Colors.grey,
                    height: 80,
                    width: 120,
                    alignment: Alignment.center, // Centered your text visually
                    child: Text(
                      _selectedRole,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 40),
                    ),
                  ),
                  const SizedBox(width: 16), // Added spacing between UI elements
                  ElevatedButton.icon(
                    onPressed: swipe,
                    icon: const Icon(Icons.change_circle),
                    label: const Text('Swap Role'),
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email Address', // Updated label
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Enter password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _login,
                child: const Text('Login'),
              ),
              if (_selectedRole == 'User')
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterScreen(),
                      ),
                    );
                  },
                  child: const Text('Don\'t have an account? Register here'),
                ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  await AuthSeeder.initializeMockUsers();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mock users initialized in Supabase!')),
                    );
                  }
                },
                child: const Text('Seed Admin & User Accounts'),
              )
            ],
          ),
        ),
      ),
    );
  }
}