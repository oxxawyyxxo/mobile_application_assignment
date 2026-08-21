import 'package:flutter/material.dart';
import '../models/user_model.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController fullnameCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  
  String? _validatePassword(String? value){
    if (value == null || value.isEmpty){
      return 'Password is required';
    }
    if(value.length < 8){
      return  'Password must at least 8 characters long';
    }
    if(!value.contains(RegExp(r'[A-Z]'))){
      return 'Must contain at least 1 uppercase letter';
    }
    if(!value.contains(RegExp(r'[a-z]'))){
      return 'Must contain at least 1 lower case';
    }
    if(!value.contains(RegExp(r'[\\!@#$&*~%^().,]'))){
      return 'Must return at least 1 special character';
    }
    return null;
  }
  
  void _register(){
    if(_formKey.currentState!.validate()){
      mockUserDatabase.add(
        AppUser(
            username: usernameCtrl.text.trim(), 
            fullName: fullnameCtrl.text.trim(), 
            password: passwordCtrl.text.trim(), 
            role: 'User' // always assigned as User in Global Registration
        )
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Registration Successfully')
        )
      );
      Navigator.pop(context);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Registration'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username',hint: Text('enter username here')),
                  validator: (value){
                    if (value == null || value.isEmpty){
                      return 'Do not leave blank';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12,),
                TextFormField(
                  controller: fullnameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name',hint: Text('enter name here')),
                  validator: (value){
                    if (value == null || value.isEmpty){
                      return 'Do not leave blank';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12,),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password',hint: Text('enter password here')),
                  validator: _validatePassword,
                  obscureText: true,
                ),
                const SizedBox(height: 12,),
                ElevatedButton(
                    onPressed: _register, 
                    child: const Text('Register Now')
                )
              ],
            )
        ),
      ),
    );
  }
}
