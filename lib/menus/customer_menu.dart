import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/auth/login_screen.dart';

class CustomerMenu extends StatefulWidget {
  final String name;

  const CustomerMenu({Key? key, required this.name}) : super(key: key);

  @override
  State<CustomerMenu> createState() => _CustomerMenuState();
}

class _CustomerMenuState extends State<CustomerMenu> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Menu'),backgroundColor: Colors.blue,),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
             Text(
                'Hi, ${widget.name}',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
             ),
            const SizedBox(height: 20,),
            ElevatedButton(
                onPressed: (){
                  Navigator.pushAndRemoveUntil(
                      context, 
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      ((route) => false)
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red
                ),
                child: const Text('Logout', style: TextStyle(color: Colors.white),)
            )
          ],
        ),
      ),
    );
  }
}
