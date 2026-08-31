import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});

  @override
  State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _amountCtrl = TextEditingController();
  bool _isLoading = false;
  double? _currentBalance;

  final List<double> _quickAmounts = [10, 20, 50, 100, 200];

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final profile = await _supabase
        .from('user_profiles')
        .select('credit_balance')
        .eq('id', user.id)
        .single();
    if (mounted) {
      setState(() {
        _currentBalance = (profile['credit_balance'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  Future<void> _confirmTopUp() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid RM amount.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _supabase.rpc('topup_credit', params: {
        'p_amount': amount,
        'p_method': 'qr_scan',
      });

      if (!mounted) return;

      setState(() {
        _currentBalance = (result as num).toDouble();
        _amountCtrl.clear();
      });

      final pointsEarned = amount.floor(); // matches the SQL floor(p_amount)

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Top up successful! +RM ${amount.toStringAsFixed(2)} · +$pointsEarned pts',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Top Up Failed'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Top Up Credit')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current balance card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Current Balance', style: TextStyle(fontSize: 16)),
                    Text(
                      _currentBalance == null
                          ? '...'
                          : 'RM ${_currentBalance!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Scan to Pay',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // QR placeholder - replace this Container with Image.network/Image.asset later
            Container(
              height: 220,
              width: 220,
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'images/qr_code.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const Divider(height: 32, thickness: 2),

            const Text(
              'Enter Amount (RM)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                prefixText: 'RM ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 12),

            // Quick amount chips
            Wrap(
              spacing: 8,
              children: _quickAmounts.map((amt) {
                return ActionChip(
                  label: Text('RM ${amt.toStringAsFixed(0)}'),
                  onPressed: () {
                    _amountCtrl.text = amt.toStringAsFixed(2);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _confirmTopUp,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Confirm Top Up', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}