import 'package:flutter/material.dart';

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
        title: const Text('Staff Dashboard'),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Text(
          'Hi, Staff ${widget.name}.', // Use widget.name here
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}