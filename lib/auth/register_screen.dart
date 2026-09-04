import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController fullnameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool _isLoading = false;

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Must contain at least 1 uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Must contain at least 1 lower case';
    }
    if (!value.contains(RegExp(r'[\\!@#$&*~%^().,]'))) {
      return 'Must return at least 1 special character';
    }
    return null;
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // 1. Sign up user in Supabase Auth
        final AuthResponse response = await _supabase.auth.signUp(
          email: emailCtrl.text.trim(),
          password: passwordCtrl.text,
          data: {
            'full_name': fullnameCtrl.text.trim(),
            'role': 'User',
          },
        );

        // 2. Explicitly insert into user_profiles table (Backup for trigger)
        if (response.user != null) {
          await _supabase.from('user_profiles').upsert({
            'id': response.user!.id,
            'email': emailCtrl.text.trim(),
            'full_name': fullnameCtrl.text.trim(),
            'role': 'User',
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration successful! Please login.')),
          );
          Navigator.pop(context);
        }
      } on AuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('User Registration')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email Address'),
                validator: (val) => val == null || val.isEmpty || !val.contains('@') ? 'Enter a valid email' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: fullnameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (val) => val == null || val.isEmpty ? 'Enter your full name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: _validatePassword,
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _register,
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}