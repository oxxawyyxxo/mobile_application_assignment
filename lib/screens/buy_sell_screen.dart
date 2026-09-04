import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/back_to_menu.dart';

enum TradeSide { buy, sell }

/// Two entry modes:
/// - byShares: user enters a whole/fractional share quantity directly
/// - byAmount: user enters an RM amount and we compute fractional shares
enum EntryMode { byShares, byAmount }

class BuySellScreen extends StatefulWidget {
  final String symbol;
  final double currentPrice;

  const BuySellScreen({
    super.key,
    required this.symbol,
    required this.currentPrice,
  });

  @override
  State<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends State<BuySellScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _inputCtrl = TextEditingController();

  TradeSide _side = TradeSide.buy;
  EntryMode _mode = EntryMode.byAmount;
  bool _isLoading = false;

  double? _creditBalance;
  double _heldQuantity = 0;

  @override
  void initState() {
    super.initState();
    _fetchAccountInfo();
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAccountInfo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final profile = await _supabase
        .from('user_profiles')
        .select('credit_balance')
        .eq('id', user.id)
        .single();

    final holding = await _supabase
        .from('portfolio_holdings')
        .select('quantity')
        .eq('user_id', user.id)
        .eq('symbol', widget.symbol)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _creditBalance = (profile['credit_balance'] as num?)?.toDouble() ?? 0.0;
        _heldQuantity = (holding?['quantity'] as num?)?.toDouble() ?? 0.0;
      });
    }
  }

  // Derived preview numbers based on current input + mode
  double get _quantity {
    final val = double.tryParse(_inputCtrl.text) ?? 0.0;
    if (_mode == EntryMode.byShares) return val;
    if (widget.currentPrice <= 0) return 0;
    return val / widget.currentPrice;
  }

  double get _amount {
    final val = double.tryParse(_inputCtrl.text) ?? 0.0;
    if (_mode == EntryMode.byAmount) return val;
    return val * widget.currentPrice;
  }

  // Switches to "by shares" mode and fills the exact held quantity, so the
  // sell RPC receives p_quantity directly rather than a derived RM amount -
  // avoids rounding mismatches that could leave a dust balance behind.
  void _fillSellAll() {
    setState(() {
      _mode = EntryMode.byShares;
      _inputCtrl.text = _heldQuantity.toString();
    });
  }

  Future<void> _confirmTrade() async {
    final rawInput = double.tryParse(_inputCtrl.text);
    if (rawInput == null || rawInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid value.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final params = <String, dynamic>{
        'p_symbol': widget.symbol,
        'p_price': widget.currentPrice,
      };
      if (_mode == EntryMode.byShares) {
        params['p_quantity'] = rawInput;
      } else {
        params['p_amount'] = rawInput;
      }

      final fnName = _side == TradeSide.buy ? 'buy_stock' : 'sell_stock';
      final result = await _supabase.rpc(fnName, params: params);

      if (!mounted) return;

      final qty = (result['quantity'] as num).toDouble();
      final amt = (result['amount'] as num).toDouble();

      await _fetchAccountInfo();
      _inputCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_side == TradeSide.buy ? "Bought" : "Sold"} '
                '${qty.toStringAsFixed(4)} shares for RM ${amt.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_side == TradeSide.buy ? 'Buy Failed' : 'Sell Failed'),
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
      appBar: AppBar(
        title: Text('${widget.symbol} · Trade'),
        actions: const [
          BackToCustomerMenuButton(),
          SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account snapshot
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('Credit Balance'),
                        Text(
                          _creditBalance == null
                              ? '...'
                              : 'RM ${_creditBalance!.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        Text('${widget.symbol} Held'),
                        Text(
                          _heldQuantity.toStringAsFixed(4),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Price'),
                        Text(
                          'RM ${widget.currentPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Buy / Sell toggle
            SegmentedButton<TradeSide>(
              segments: const [
                ButtonSegment(
                  value: TradeSide.buy,
                  label: Text('Buy'),
                  icon: Icon(Icons.trending_up),
                ),
                ButtonSegment(
                  value: TradeSide.sell,
                  label: Text('Sell'),
                  icon: Icon(Icons.trending_down),
                ),
              ],
              selected: {_side},
              onSelectionChanged: (s) => setState(() => _side = s.first),
            ),
            const SizedBox(height: 16),

            // Entry mode toggle
            SegmentedButton<EntryMode>(
              segments: const [
                ButtonSegment(
                  value: EntryMode.byAmount,
                  label: Text('By RM Amount'),
                ),
                ButtonSegment(
                  value: EntryMode.byShares,
                  label: Text('By Shares'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() {
                  _mode = s.first;
                  _inputCtrl.clear();
                });
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _inputCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: _mode == EntryMode.byAmount ? 'RM ' : null,
                suffixText: _mode == EntryMode.byShares ? 'shares' : null,
                labelText: _mode == EntryMode.byAmount
                    ? 'Amount to ${_side == TradeSide.buy ? "spend" : "sell"}'
                    : 'Number of shares',
                border: const OutlineInputBorder(),
                hintText: _mode == EntryMode.byAmount ? '0.00' : '0.0000',
              ),
            ),

            // Sell All quick action - only relevant when selling and holding something
            if (_side == TradeSide.sell && _heldQuantity > 0) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _fillSellAll,
                  icon: const Icon(Icons.playlist_remove, size: 18),
                  label: Text(
                    'Sell All (${_heldQuantity.toStringAsFixed(4)} shares)',
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Live preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Shares:'),
                        Text(_quantity.toStringAsFixed(4)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _side == TradeSide.buy ? 'Total Cost:' : 'Total Proceeds:',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'RM ${_amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _confirmTrade,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                _side == TradeSide.buy ? Colors.green : Colors.red,
              ),
              child: Text(
                _side == TradeSide.buy ? 'Confirm Buy' : 'Confirm Sell',
                style: const TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}