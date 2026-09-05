import 'package:flutter/material.dart';
import '../menus/customer_menu.dart';

class BackToCustomerMenuButton extends StatelessWidget {
  const BackToCustomerMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.storefront_outlined),
      tooltip: 'Back to Customer Menu',
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const CustomerMenu()),
              (route) => false,
        );
      },
    );
  }
}