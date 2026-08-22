import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/auth/login_screen.dart';

class StaffMenu extends StatefulWidget {
  final String name;

  const StaffMenu({Key? key, required this.name}) : super(key: key);

  @override
  State<StaffMenu> createState() => _StaffMenuState();
}

class _StaffMenuState extends State<StaffMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Menu'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Hi, Staff ${widget.name}.', // Use widget.name here
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20,),
            ElevatedButton(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Logout', style: TextStyle(color: Colors.white)),
            ),
          ]
        ),
      ),
    );
  }
}