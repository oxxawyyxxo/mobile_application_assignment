import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/petrol_service.dart';

class BuyPetrolScreen extends StatefulWidget {
  const BuyPetrolScreen({super.key});

  @override
  State<BuyPetrolScreen> createState() => _BuyPetrolScreenState();
}

class _BuyPetrolScreenState extends State<BuyPetrolScreen> {
  final PetrolService _petrolService = PetrolService();
  final _supabase = Supabase.instance.client;
  final TextEditingController _litresCtrl = TextEditingController();

  String _selectedFuel = 'RON 95';
  bool _redeemPoints = false;
  bool _isLoading = false;

  // Real-time calculation variables
  int _currentPoints = 0;
  double _pricePerLitre = 2.05; // Default for RON95
  double _rawTotal = 0.0;
  double _discountAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    _litresCtrl.addListener(_calculatePreview);
  }

  @override
  void dispose() {
    _litresCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final profile = await _supabase
          .from('user_profiles')
          .select('points')
          .eq('id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _currentPoints = profile['points'] ?? 0;
        });
      }
    }
    _updateFuelPrice(_selectedFuel);
  }

  // Update the price per litre based on the selected dropdown
  Future<void> _updateFuelPrice(String fuelType) async {
    try {
      final fuelData = await _supabase
          .from('fuel_inventory')
          .select('price')
          .eq('fuel_type', fuelType)
          .maybeSingle();

      if (fuelData == null) {
        debugPrint('Warning: Fuel type "$fuelType" not found in database.');
        return;
      }

      if (mounted) {
        setState(() {
          _pricePerLitre = (fuelData['price'] as num).toDouble();
          _calculatePreview();
        });
      }
    } catch (e) {
      debugPrint('Error fetching fuel price: $e');
    }
  }

  // Live calculation for the UI preview
  void _calculatePreview() {
    final litres = double.tryParse(_litresCtrl.text) ?? 0.0;
    _rawTotal = litres * _pricePerLitre;

    if (_redeemPoints && _currentPoints >= 100) {
      int pointsToRedeem = (_currentPoints / 100).floor() * 100;
      _discountAmount = pointsToRedeem / 100.0;

      // Ensure discount doesn't exceed the total price
      if (_discountAmount > _rawTotal) {
        _discountAmount = _rawTotal;
      }
    } else {
      _discountAmount = 0.0;
    }
    setState(() {}); // Trigger rebuild to show new numbers
  }

  void _processPurchase() async {
    final litres = double.tryParse(_litresCtrl.text);
    if (litres == null || litres <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount of litres.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Await the service
      String? error = await _petrolService.buyPetrol(
        fuelType: _selectedFuel,
        requestedLitres: litres,
        redeemPoints: _redeemPoints,
      );

      if (!mounted) return;

      if (error != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Purchase Failed'),
            content: Text(error),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        await _fetchUserData();
        setState(() {
          _litresCtrl.clear();
          _redeemPoints = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase Successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text('An unexpected error occurred: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalTotal = _rawTotal - _discountAmount;

    return Scaffold(
      appBar: AppBar(title: const Text('Buy Petrol')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Balance Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Your Membership Balance', style: TextStyle(fontSize: 16)),
                    Text(
                      '$_currentPoints Points',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                    const Text('Earn 1 point for every RM 1 spent!'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Fuel Selection
            DropdownButtonFormField<String>(
              value: _selectedFuel,
              items: ['RON 95', 'RON 97', 'Diesel']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedFuel = val);
                  _updateFuelPrice(val);
                }
              },
              decoration: const InputDecoration(labelText: 'Fuel Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),

            // Litre Input
            TextField(
              controller: _litresCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount of Litres',
                suffixText: 'L',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Point Redemption Toggle
            CheckboxListTile(
              title: const Text('Redeem Points'),
              subtitle: Text('100 pts = RM 1.00 (Max discount: RM ${_discountAmount.toStringAsFixed(2)})'),
              value: _redeemPoints,
              onChanged: _currentPoints >= 100
                  ? (val) {
                setState(() => _redeemPoints = val ?? false);
                _calculatePreview();
              }
                  : null,
            ),

            const Divider(height: 32, thickness: 2),

            const Text('Order Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Subtotal:'),
              Text('RM ${_rawTotal.toStringAsFixed(2)}'),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Discount:', style: TextStyle(color: Colors.green)),
              Text('- RM ${_discountAmount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Total to Pay:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                'RM ${finalTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ]),

            const SizedBox(height: 24),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _processPurchase,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm Purchase', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}