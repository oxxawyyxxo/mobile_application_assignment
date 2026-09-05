import 'package:flutter/material.dart';
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
  bool _obscurePassword = true;

  // Changed to email controller because Supabase requires emails
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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

  void _showErrorDialog(String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.primary, size: 30),

            SizedBox(width: 10),

            const Text('Unable to sign in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 28,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              'Welcome back',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sign in to continue to your account.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Role selector
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'User',
                        icon: Icon(Icons.person_outline),
                        label: Text('User'),
                      ),
                      ButtonSegment(
                        value: 'Staff',
                        icon: Icon(Icons.badge_outlined),
                        label: Text('Staff'),
                      ),
                    ],
                    selected: {_selectedRole},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) {
                      setState(() {
                        _selectedRole = selection.first;
                      });
                    },
                  ),

                  const SizedBox(height: 28),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.email,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'name@example.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter your email address';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [
                      AutofillHints.password,
                    ],
                    onFieldSubmitted: (_) {
                      if (!_isLoading) {
                        _login();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon:
                      const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Show password'
                            : 'Hide password',
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                            !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colorScheme.onPrimary,
                        )
                      )
                          : const Text('Sign in'),
                    ),
                  ),

                  // Registration
                  if (_selectedRole == 'User') ...[
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'New here?',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}