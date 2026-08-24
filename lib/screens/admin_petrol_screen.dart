import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPetrolScreen extends StatefulWidget {
  const AdminPetrolScreen({super.key});

  @override
  State<AdminPetrolScreen> createState() => _AdminPetrolScreenState();
}

class _AdminPetrolScreenState extends State<AdminPetrolScreen> {
  final _supabase = Supabase.instance.client;

  void _showUpdateStockDialog(String id, String fuelType, double currentStock){
    final controller = TextEditingController(text: currentStock.toString());

    showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Update Stock: $fuelType'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true
            ),
            decoration: const InputDecoration(
              labelText: 'Stock in litres'
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')
            ),
            ElevatedButton(
                onPressed: () async {
                  final newStock = double.tryParse(controller.text) ?? currentStock;
                  await _supabase
                  .from('fuel_inventory')
                  .update({'stock_litres': newStock})
                  .eq('id', id);

                  if (mounted){
                    Navigator.pop(context);
                  }
                },
                child: const Text("Save")
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Fuel Stock'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
          stream: _supabase.from('fuel_inventory').stream(primaryKey: ['id']),
          builder: (context, snapshot){
            if (!snapshot.hasData){
              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                );
              }

              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final inventory = snapshot.data!;

            if (inventory.isEmpty) {
              return const Center(
                child: Text('No fuel inventory found.'),
              );
            }

            return ListView.builder(
                itemCount: inventory.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (context, index){
                final item = inventory[index];
                final String id = item['id'];
                final String fuelType = item['fuel_type'];
                final double stock = (item['stock_litres'] as num).toDouble();
                final bool isAvailable = item['is_available'] ?? false;
                final double price = (item['price'] as num).toDouble();
                
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(fuelType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text('Price: RM ${price.toStringAsFixed(2)} / Litre\nStock: ${stock.toStringAsFixed(1)} L'),
                          trailing: Switch(
                              value: isAvailable,
                              onChanged: (val) async {
                                await _supabase
                                    .from('fuel_inventory')
                                    .update({'is_available' : val})
                                    .eq('id', id);
                              }
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.edit),
                              label: const Text('Adjust Stock'),
                              onPressed: () => _showUpdateStockDialog(id, fuelType, stock),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }
      ),
    );
  }
}
