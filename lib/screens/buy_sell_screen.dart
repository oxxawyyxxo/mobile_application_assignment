import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/stock_data_service.dart';
import '../widgets/app_bottom_nav.dart';
import '../menus/customer_menu.dart';
import 'stock_chart_screen.dart';

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
    this.symbol = 'IBM',
    this.currentPrice = 0.0,
  });

  @override
  State<BuySellScreen> createState() => _BuySellScreenState();
}

class _BuySellScreenState extends State<BuySellScreen> {
  final _supabase = Supabase.instance.client;
  final TextEditingController _inputCtrl = TextEditingController();

  late String _symbol;
  late double _currentPrice;
  bool _isFetchingPrice = false;

  TradeSide _side = TradeSide.buy;
  EntryMode _mode = EntryMode.byAmount;
  bool _isLoading = false;

  double? _creditBalance;
  double _heldQuantity = 0;

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol;
    _currentPrice = widget.currentPrice;
    _fetchAccountInfo();
    if (_currentPrice <= 0) {
      _fetchCurrentPrice();
    }
    _inputCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentPrice() async {
    setState(() => _isFetchingPrice = true);
    try {
      final prices = await StockDataService.fetchStockPrices(_symbol);
      if (prices.isNotEmpty && mounted) {
        setState(() {
          _currentPrice = prices.first.close;
        });
      }
    } catch (e) {
      debugPrint('Error fetching price for $_symbol: $e');
    } finally {
      if (mounted) setState(() => _isFetchingPrice = false);
    }
  }

  Future<void> _openSearch() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const StockSearchSheet(),
    );

    if (selected != null && selected != _symbol) {
      setState(() {
        _symbol = selected;
        _currentPrice = 0.0;
        _inputCtrl.clear();
      });
      _fetchAccountInfo();
      _fetchCurrentPrice();
    }
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
        .eq('symbol', _symbol)
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
    if (_currentPrice <= 0) return 0;
    return val / _currentPrice;
  }

  double get _amount {
    final val = double.tryParse(_inputCtrl.text) ?? 0.0;
    if (_mode == EntryMode.byAmount) return val;
    return val * _currentPrice;
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

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getFormattedErrorMessage(Object e, TradeSide side) {
    String rawMessage = '';
    if (e is PostgrestException) {
      rawMessage = e.message;
    } else {
      rawMessage = e.toString();
      final match =
          RegExp(r'message:\s*(.+?)(,\s*code:|$)').firstMatch(rawMessage);
      if (match != null) {
        rawMessage = match.group(1)?.trim() ?? rawMessage;
      }
    }

    final lower = rawMessage.toLowerCase();

    if (side == TradeSide.sell) {
      if (lower.contains('insufficient holding') ||
          lower.contains('insufficient share') ||
          lower.contains('not enough share') ||
          lower.contains('exceeds')) {
        return 'You do not have enough shares of $_symbol to complete this sale.\n\nCurrently held: ${_heldQuantity.toStringAsFixed(6)} shares.';
      }
      if (lower.contains('not found') || lower.contains('no holding')) {
        return 'You do not hold any shares of $_symbol in your portfolio.';
      }
    } else {
      if (lower.contains('insufficient balance') ||
          lower.contains('insufficient credit') ||
          lower.contains('not enough credit')) {
        final balText = _creditBalance != null
            ? '\n\nAvailable Balance: RM ${_creditBalance!.toStringAsFixed(2)}'
            : '';
        return 'You do not have sufficient credit balance to complete this purchase.$balText';
      }
    }

    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('connection')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }

    if (lower.contains('timeout')) {
      return 'The request timed out. Please try again later.';
    }

    final cleaned = rawMessage
        .replaceAll(
            RegExp(r'^(Exception|PostgrestException|AuthException):\s*'), '')
        .trim();
    return cleaned.isNotEmpty
        ? cleaned
        : 'An unexpected error occurred. Please try again.';
  }

  Future<void> _confirmTrade() async {
    final rawInput = double.tryParse(_inputCtrl.text);
    if (rawInput == null || rawInput <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid value.')),
        );
      }
      return;
    }

    if (_currentPrice <= 0) {
      _showErrorDialog(
        _side == TradeSide.buy ? 'Buy Failed' : 'Sell Failed',
        'Stock price for $_symbol is unavailable or invalid. Please wait for price data to refresh.',
      );
      return;
    }

    // Pre-validations for sell and buy
    if (_side == TradeSide.sell) {
      if (_heldQuantity <= 0) {
        _showErrorDialog(
          'Sell Failed',
          'You do not hold any shares of $_symbol to sell.',
        );
        return;
      }

      final sellQuantity = _mode == EntryMode.byShares
          ? rawInput
          : double.parse((rawInput / _currentPrice).toStringAsFixed(6));
      if (sellQuantity > _heldQuantity) {
        _showErrorDialog(
          'Sell Failed',
          'Insufficient holdings.\n\nYou requested to sell ${sellQuantity.toStringAsFixed(6)} shares, but you only hold ${_heldQuantity.toStringAsFixed(6)} shares of $_symbol.',
        );
        return;
      }
    } else {
      final totalCost = _amount;
      if (_creditBalance != null && totalCost > _creditBalance!) {
        _showErrorDialog(
          'Buy Failed',
          'Insufficient credit balance.\n\nTotal cost: RM ${totalCost.toStringAsFixed(2)}\nAvailable balance: RM ${_creditBalance!.toStringAsFixed(2)}.',
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final params = <String, dynamic>{
        'p_symbol': _symbol,
        'p_price': _currentPrice,
      };
      if (_mode == EntryMode.byShares) {
        params['p_quantity'] = rawInput;
      } else {
        params['p_amount'] = rawInput;
        // Compute p_quantity with 6 decimal places precision so that
        // sell_stock does not truncate/round quantity to 4 decimal places.
        params['p_quantity'] =
            double.parse((rawInput / _currentPrice).toStringAsFixed(6));
      }

      final fnName = _side == TradeSide.buy ? 'buy_stock' : 'sell_stock';
      final result = await _supabase.rpc(fnName, params: params);

      if (!mounted) return;

      final qty = (result['quantity'] as num).toDouble();
      final amt = (result['amount'] as num).toDouble();

      await _fetchAccountInfo();
      if (!mounted) return;

      _inputCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_side == TradeSide.buy ? "Bought" : "Sold"} '
                '${qty.toStringAsFixed(6)} shares for RM ${amt.toStringAsFixed(2)}',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(
        _side == TradeSide.buy ? 'Buy Failed' : 'Sell Failed',
        _getFormattedErrorMessage(e, _side),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                '$_symbol · Trade',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(
        currentIndex: 2,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSearch,
        icon: const Icon(Icons.search),
        label: const Text('Stock'),
      ),
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
                    // Column(
                    //   children: [
                    //     const Text('Credit Balance'),
                    //     Text(
                    //       _creditBalance == null
                    //           ? '...'
                    //           : 'RM ${_creditBalance!.toStringAsFixed(2)}',
                    //       style: const TextStyle(
                    //           fontSize: 18, fontWeight: FontWeight.bold),
                    //     ),
                    //   ],
                    // ),
                    Column(
                      children: [
                        Text('$_symbol Held'),
                        Text(
                          _heldQuantity.toStringAsFixed(6),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Price'),
                        Text(
                          _isFetchingPrice
                              ? '...'
                              : 'RM ${_currentPrice.toStringAsFixed(2)}',
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
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  _mode == EntryMode.byAmount
                      ? RegExp(r'^\d{0,9}(\.\d{0,2})?')
                      : RegExp(r'^\d{0,9}(\.\d{0,6})?'),
                ),
              ],
              decoration: InputDecoration(
                prefixText: _mode == EntryMode.byAmount ? 'RM ' : null,
                suffixText: _mode == EntryMode.byShares ? 'shares' : null,
                labelText: _mode == EntryMode.byAmount
                    ? 'Amount to ${_side == TradeSide.buy ? "spend" : "sell"}'
                    : 'Number of shares',
                border: const OutlineInputBorder(),
                hintText: _mode == EntryMode.byAmount ? '0.00' : '0.000000',
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
                    'Sell All (${_heldQuantity.toStringAsFixed(6)} shares)',
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
                        Text(_quantity.toStringAsFixed(6)),
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