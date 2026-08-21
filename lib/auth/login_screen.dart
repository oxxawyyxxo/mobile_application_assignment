import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../menus/customer_menu.dart';
import '../menus/staff_menu.dart';
import  'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  String _selectedRole = "User";

  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  void _login(){
    if (_formKey.currentState!.validate()){
      final _username = _usernameCtrl.text.trim();
      final _password = _passwordCtrl.text;

      final matchingUser = mockUserDatabase.firstWhere(
          (u) => u.username.toUpperCase() == _username.toUpperCase() &&
              u.password == _password &&
              u.role == _selectedRole,

        orElse: () => AppUser(
            username: '',
            fullName: '',
            password: '',
            role: ''
        )
      );

      if (matchingUser.username.isEmpty){
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: const Text('Invalid username, password or role'),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
        return;
      }

      if(_selectedRole == 'Staff'){
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StaffMenu(name: matchingUser.fullName)
            ),
        );
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (_) => CustomerMenu(name: matchingUser.fullName),
            )
        );
      }
    }
  }

  void swipe(){
    setState(() {
      if(_selectedRole == 'User'){
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
                    child: Text(_selectedRole, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 40),),
                    height: 80,
                    width: 120,
                  ),
                  ElevatedButton.icon(
                      onPressed: swipe,
                      icon: const Icon(Icons.change_circle),
                    label: const Text('Swap Role'),
                  )
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                ),
                validator: (val){
                  if(val == null || val.isEmpty){
                    return 'Enter username';
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
                validator: (val){
                  if(val == null || val.isEmpty){
                    return 'Enter password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                  onPressed: _login,
                  child: Text('Login')
              ),
              if(_selectedRole == 'User')
                TextButton(
                    onPressed: (){
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RegisterScreen()
                          )
                      );
                    },
                  child: Text('Don\'t have an account? Register here'),
                )
            ],
          )
        ),
      ),
    );
  }
}
