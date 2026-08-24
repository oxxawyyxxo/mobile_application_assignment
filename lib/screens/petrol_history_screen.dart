import 'package:flutter/material.dart';
import '../services/local_db_service.dart';

class PetrolHistoryScreen extends StatefulWidget {
  const PetrolHistoryScreen({super.key});

  @override
  State<PetrolHistoryScreen> createState() => _PetrolHistoryScreenState();
}

class _PetrolHistoryScreenState extends State<PetrolHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final db = await LocalDbService.database;
    return await db.query('cached_transactions', orderBy: 'created_at DESC');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Petrol Purchase History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No past transactions found locally.'),
            );
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            itemCount: transactions.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final double litres = (tx['litres'] as num).toDouble();
              final double total = (tx['total_price'] as num).toDouble();
              final String date = tx['created_at'] != null
                  ? tx['created_at'].toString().split('T').first
                  : 'N/A';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      tx['fuel_type'] == 'Diesel'
                          ? Icons.local_shipping
                          : Icons.local_gas_station,
                    ),
                  ),
                  title: Text('${tx['fuel_type']} - ${litres.toStringAsFixed(1)} L'),
                  subtitle: Text('Date: $date'),
                  trailing: Text(
                    'RM ${total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}