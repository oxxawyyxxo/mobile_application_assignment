import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'stock_chart_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../menus/customer_menu.dart';
import '../models/transaction_model.dart';
import '../models/stock_price_model.dart';
import '../services/stock_data_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _holdingsFuture;
  late Future<List<TransactionEntry>> _transactionsFuture;
  double? _totalShareValue;

  @override
  void initState() {
    super.initState();
    _holdingsFuture = _fetchHoldings();
    _transactionsFuture = _fetchTransactions();
  }

  Future<List<Map<String, dynamic>>> _fetchHoldings() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final rows = await _supabase
        .from('portfolio_holdings')
        .select('symbol, quantity, avg_price')
        .eq('user_id', user.id)
        .gt('quantity', 0)
        .order('symbol');

    final holdings = List<Map<String, dynamic>>.from(rows);
    if (holdings.isEmpty) {
      if (mounted) {
        setState(() {
          _totalShareValue = 0.0;
        });
      }
      return [];
    }

    final symbols = holdings.map((h) => h['symbol'] as String).toList();
    Map<String, List<StockPrice>> pricesMap = {};
    try {
      pricesMap = await StockDataService.fetchMultipleStockPrices(symbols);
    } catch (e) {
      debugPrint('Error fetching stock prices for portfolio: $e');
    }

    double totalWorth = 0.0;
    for (final h in holdings) {
      final symbol = h['symbol'] as String;
      final quantity = (h['quantity'] as num).toDouble();
      final avgPrice = (h['avg_price'] as num).toDouble();

      final prices = pricesMap[symbol];
      final currentPrice = (prices != null && prices.isNotEmpty)
          ? prices.first.close
          : avgPrice;

      final marketValue = quantity * currentPrice;
      h['current_price'] = currentPrice;
      h['market_value'] = marketValue;
      totalWorth += marketValue;
    }

    if (mounted) {
      setState(() {
        _totalShareValue = totalWorth;
      });
    }

    return holdings;
  }

  Future<List<TransactionEntry>> _fetchTransactions() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    // Fetch both trade history and top-up history, then merge + sort
    // client-side since they're separate tables.
    final trades = await _supabase
        .from('stock_trades')
        .select('symbol, side, quantity, price, amount, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(30);

    final topups = await _supabase
        .from('topup_transactions')
        .select('id, amount, status, method, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(30);

    // refund_status isn't a column on topup_transactions - derive it by
    // looking up any refund_requests row tied to each top-up.
    final refundRows = await _supabase
        .from('refund_requests')
        .select('topup_transaction_id, status')
        .eq('user_id', user.id);

    final refundStatusByTopupId = <String, String>{
      for (final r in refundRows)
        if (r['topup_transaction_id'] is String)
          r['topup_transaction_id'] as String: r['status'] as String? ?? 'pending',
    };

    final entries = <TransactionEntry>[
      for (final t in trades)
        if (TransactionEntry.tryTrade(t) != null) TransactionEntry.tryTrade(t)!,
      for (final t in topups)
        if (TransactionEntry.tryTopup(t, refundStatusByTopupId) != null)
          TransactionEntry.tryTopup(t, refundStatusByTopupId)!,
    ];

    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<void> _showRefundNotice() async {
    // Fast local check: if we already know (from the last transactions
    // fetch) that a refund is pending, deny immediately without even
    // calling the server. This is just a UX shortcut - request_refund()
    // in the DB still enforces this for real, so it's safe if this cache
    // is stale.
    final transactions = await _transactionsFuture;
    final hasPendingRefund = transactions.any(
          (t) => t.isTopup && t.refundStatus == 'pending',
    );
    if (hasPendingRefund) {
      if (!mounted) return;
      _showDenialDialog(
        'You already have a pending refund request. Please wait for it to be reviewed.',
      );
      return;
    }

    // Check eligibility first - if it fails, deny immediately without
    // showing the "Continue" option at all.
    Map<String, dynamic> eligibility;
    try {
      eligibility = await _supabase.rpc('check_refund_eligibility');
    } catch (e) {
      if (!mounted) return;
      _showDenialDialog(_extractErrorMessage(e));
      return;
    }

    final bool eligible = eligibility['eligible'] as bool? ?? false;

    if (!eligible) {
      final reason = eligibility['reason'] as String? ??
          'This top-up is not eligible for a refund.';
      if (!mounted) return;
      _showDenialDialog(reason);
      return;
    }

    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refund Request Requirements'),
        content: const Text(
          'You can only request a refund if:\n\n'
              '• Your most recent top-up was made within the last 3 days.\n'
              '• You have not bought or sold any stock since that top-up '
              '(it must be your very last transaction).\n\n'
              'This top-up meets those requirements. Submit the refund request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      await _submitRefundRequest();
    }
  }

  void _showDenialDialog(String reason) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Refund Not Eligible'),
        content: Text(
          'Requirements for a refund:\n\n'
              '• Most recent top-up must be within the last 3 days.\n'
              '• No stock trades since that top-up.\n\n'
              'Your request was denied because:\n$reason',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  bool _isSubmittingRefund = false;

  Future<void> _submitRefundRequest() async {
    if (_isSubmittingRefund) return; // guard against double-tap races
    setState(() => _isSubmittingRefund = true);

    try {
      final result = await _supabase.rpc('request_refund');
      final amount = (result['amount'] as num).toDouble();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund request submitted for RM ${amount.toStringAsFixed(2)}. '
                'Awaiting admin review.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      // The RPC's raised exception message surfaces here, e.g. "Refund
      // window has expired" or "You already have a pending refund request".
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Refund Not Eligible'),
          content: Text(_extractErrorMessage(e)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingRefund = false);
    }
  }

  // Supabase RPC errors come wrapped (e.g. PostgrestException); strip down
  // to just the raised message for a cleaner dialog.
  String _extractErrorMessage(Object e) {
    final text = e.toString();
    final match = RegExp(r'message:\s*(.+?)(,\s*code:|$)').firstMatch(text);
    return match?.group(1)?.trim() ?? text;
  }

  Future<void> _refresh() async {
    setState(() {
      _totalShareValue = null;
      _holdingsFuture = _fetchHoldings();
      _transactionsFuture = _fetchTransactions();
    });
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
                'My Portfolio',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      const Text('Total Share Value', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        _totalShareValue == null
                            ? '...'
                            : 'RM ${_totalShareValue!.toStringAsFixed(2)}',
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isSubmittingRefund ? null : _showRefundNotice,
                icon: const Icon(Icons.undo),
                label: const Text('Request Refund for Last Top-Up'),
              ),
              const SizedBox(height: 20),
              const Text(
                'Holdings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _holdingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Error loading holdings:\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final holdings = snapshot.data ?? [];

                  if (holdings.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'No stocks yet.\nBuy your first stock to see it here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: holdings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final h = holdings[index];
                      final symbol = h['symbol'] as String;
                      final quantity = (h['quantity'] as num).toDouble();
                      final avgPrice = (h['avg_price'] as num).toDouble();
                      final currentPrice =
                          (h['current_price'] as num?)?.toDouble() ?? avgPrice;
                      final marketValue =
                          (h['market_value'] as num?)?.toDouble() ??
                              (quantity * avgPrice);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(symbol[0])),
                          title: Text(symbol,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${quantity.toStringAsFixed(6)} shares · RM ${currentPrice.toStringAsFixed(2)}',
                          ),
                          trailing: Text(
                            'RM ${marketValue.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StockChartScreen(symbol: symbol),
                              ),
                            );
                            _refresh();
                          },
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 24),
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<TransactionEntry>>(
                future: _transactionsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Error loading transactions:\n${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final entries = snapshot.data ?? [];

                  if (entries.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No transactions yet.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: entry.iconColor.withValues(alpha: 0.15),
                            child: Icon(entry.icon, color: entry.iconColor),
                          ),
                          title: Text(entry.title,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(entry.subtitle),
                          isThreeLine: true,
                          trailing: Text(
                            entry.amountLabel,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: entry.iconColor,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

