import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/auth/login_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/petrol_chart_screen.dart';
import '../screens/buy_petrol_screen.dart';
import '../screens/petrol_history_screen.dart';

class CustomerMenu extends StatefulWidget {
  final String name;

  const CustomerMenu({super.key, required this.name});

  @override
  State<CustomerMenu> createState() => _CustomerMenuState();
}

class _CustomerMenuState extends State<CustomerMenu> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    // TODO: implement initState
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final buttonStyle = ElevatedButton.styleFrom(
      textStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      minimumSize: const Size.fromHeight(80),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          width: 1,
          color: colorScheme.primary
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      shadowColor: colorScheme.primary
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 420
            ),
            child: Column(
              children: [
                // Logo / icon
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.verified_user_outlined,
                        size: 28,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),

                    SizedBox(width: 32),

                    Text(
                      '${widget.name}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                ElevatedButton.icon(
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Petrol Price Graph'),
                  style: buttonStyle,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PetrolChartScreen()),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  icon: const Icon(Icons.local_gas_station),
                  label: const Text('Purchase Petrol'),
                  style: buttonStyle,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BuyPetrolScreen()),
                  ),
                ),

                const SizedBox(height: 24),

                ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Purchase History'),
                  style: buttonStyle,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PetrolHistoryScreen()),
                  ),
                ),

                const SizedBox(height: 32),

                ElevatedButton.icon(
                  icon: const Icon(
                    Icons.logout_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Logout',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    shadowColor: Colors.red,
                  ),
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
