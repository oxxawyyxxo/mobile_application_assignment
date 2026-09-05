import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_bottom_nav.dart';
import '../menus/customer_menu.dart';

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

  double? _lockedAmount;

  final List<double> _quickAmounts = [10, 20, 50, 100, 200];

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _amountCtrl.addListener(() {
      if (_lockedAmount != null) {
        setState(() => _lockedAmount = null);
      }
    });
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

  void _onDonePressed() {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid RM amount.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _lockedAmount = amount);
  }

  Future<void> _confirmTopUp() async {
    final amount = _lockedAmount;
    if (amount == null) return;

    setState(() => _isLoading = true);

    try {
      final result = await _supabase.rpc('topup_credit', params: {
        'p_amount': amount,
        'p_method': 'QR Code',
      });

      if (!mounted) return;

      setState(() {
        _currentBalance = (result as num).toDouble();
        _amountCtrl.clear();
        _lockedAmount = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Top up successful! +RM ${amount.toStringAsFixed(2)}'),
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
    final colorScheme = Theme.of(context).colorScheme;
    final bool showQrStep = _lockedAmount != null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const CustomerMenu()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
            ),

            const SizedBox(width: 20),

            Expanded(
              child: Text(
                'Top Up Credit',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              'Enter Amount (RM)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountCtrl,
              enabled: !showQrStep,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,9}(\.\d{0,2})?'))],
              decoration: const InputDecoration(
                prefixText: 'RM ',
                border: OutlineInputBorder(),
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 12),

            if (!showQrStep) ...[
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
              ElevatedButton(
                onPressed: _onDonePressed,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Done', style: TextStyle(fontSize: 16)),
              ),
            ],

            if (showQrStep) ...[
              const Divider(height: 32, thickness: 2),
              Text(
                'Scan to Pay RM ${_lockedAmount!.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => setState(() => _lockedAmount = null),
                child: const Text('Change amount'),
              ),
              const SizedBox(height: 16),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _confirmTopUp,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  'Confirm Payment',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}