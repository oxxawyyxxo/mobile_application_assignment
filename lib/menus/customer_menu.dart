import 'package:flutter/material.dart';

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
      appBar: AppBar(title: const Text('Customer Dashboard'),backgroundColor: Colors.blue,),
      body: Center(
        child: Text(
          'Hi, ${widget.name}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
