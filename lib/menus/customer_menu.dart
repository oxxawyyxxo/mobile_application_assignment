import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/auth/login_screen.dart';
import 'package:mobile_application_assignment/screens/global_news_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/petrol_chart_screen.dart';
import '../screens/buy_petrol_screen.dart';
import '../screens/petrol_history_screen.dart';
import '../screens/stock_chart_screen.dart';

class CustomerMenu extends StatefulWidget {
  final String name;

  const CustomerMenu({Key? key, required this.name}) : super(key: key);

  @override
  State<CustomerMenu> createState() => _CustomerMenuState();
}

class _CustomerMenuState extends State<CustomerMenu> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _startFuelAvailabilityListener();
  }

  void _startFuelAvailabilityListener(){
    // Stream real time changes on fuel_inventory table

    _supabase
    .from('fuel_inventory')
        .stream(primaryKey: ['id'])
        .listen((data){
          for (var item in data){
            // Trigger alert if fuel is set to available with stock > 0
            if (item['is_available'] == true && (item['stock_litres'] as num) > 0) {
              if(mounted){
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('🔔 ${item['fuel_type']} is now back in stock!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 4),
                  )
                );
              }
            }
          }
    });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Welcome, ${widget.name}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.show_chart),
            label: const Text('View Gov.my Petrol Prices Graph'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PetrolChartScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.local_gas_station),
            label: const Text('Buy Petrol / Redeem Points'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BuyPetrolScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.history),
            label: const Text('Check Purchase History (Offline Compatible)'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PetrolHistoryScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.show_chart),
            label: const Text('Markets & Trading'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockChartScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: Icon(Icons.newspaper),
            label: const Text("Global News & Community"),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GlobalNewsScreen()),
            ),
          ),
          const SizedBox(height: 12),
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
        ],
      ),
    );
  }
}
