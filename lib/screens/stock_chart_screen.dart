import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/stock_price_model.dart';
import '../services/stock_data_service.dart';
import 'buy_sell_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../menus/customer_menu.dart';

enum Timeframe { fiveDay, oneMonth, threeMonth, sixMonth, oneYear, fiveYear, all }

extension TimeframeLabel on Timeframe {
  String get label {
    switch (this) {
      case Timeframe.fiveDay:
        return '5D';
      case Timeframe.oneMonth:
        return '1M';
      case Timeframe.threeMonth:
        return '3M';
      case Timeframe.sixMonth:
        return '6M';
      case Timeframe.oneYear:
        return '1Y';
      case Timeframe.fiveYear:
        return '5Y';
      case Timeframe.all:
        return 'All';
    }
  }

  /// Yahoo Finance `range` param.
  String get range {
    switch (this) {
      case Timeframe.fiveDay:
        return '5d';
      case Timeframe.oneMonth:
        return '1mo';
      case Timeframe.threeMonth:
        return '3mo';
      case Timeframe.sixMonth:
        return '6mo';
      case Timeframe.oneYear:
        return '1y';
      case Timeframe.fiveYear:
        return '5y';
      case Timeframe.all:
        return 'max';
    }
  }

  /// Yahoo Finance `interval` param.
  String get interval {
    switch (this) {
      case Timeframe.fiveDay:
        return '15m';
      case Timeframe.oneMonth:
        return '60m';
      case Timeframe.threeMonth:
        return '4h';
      case Timeframe.sixMonth:
      case Timeframe.oneYear:
        return '1d';
      case Timeframe.fiveYear:
        return '1wk';
      case Timeframe.all:
        return '1mo';
    }
  }
}

/// Static list of top stocks shown in the search sheet.
const List<Map<String, String>> kTopStocks = [
  {'symbol': 'AAPL', 'name': 'Apple Inc.'},
  {'symbol': 'MSFT', 'name': 'Microsoft Corp.'},
  {'symbol': 'GOOGL', 'name': 'Alphabet Inc.'},
  {'symbol': 'AMZN', 'name': 'Amazon.com Inc.'},
  {'symbol': 'NVDA', 'name': 'NVIDIA Corp.'},
  {'symbol': 'META', 'name': 'Meta Platforms Inc.'},
  {'symbol': 'TSLA', 'name': 'Tesla Inc.'},
  {'symbol': 'BRK.B', 'name': 'Berkshire Hathaway'},
  {'symbol': 'LLY', 'name': 'Eli Lilly and Co.'},
  {'symbol': 'V', 'name': 'Visa Inc.'},
  {'symbol': 'JPM', 'name': 'JPMorgan Chase & Co.'},
  {'symbol': 'UNH', 'name': 'UnitedHealth Group'},
  {'symbol': 'XOM', 'name': 'Exxon Mobil Corp.'},
  {'symbol': 'MA', 'name': 'Mastercard Inc.'},
  {'symbol': 'JNJ', 'name': 'Johnson & Johnson'},
  {'symbol': 'PG', 'name': 'Procter & Gamble'},
  {'symbol': 'HD', 'name': 'Home Depot Inc.'},
  {'symbol': 'AVGO', 'name': 'Broadcom Inc.'},
  {'symbol': 'MRK', 'name': 'Merck & Co.'},
  {'symbol': 'IBM', 'name': 'IBM Corp.'},
];

class StockChartScreen extends StatefulWidget {
  final String symbol;

  const StockChartScreen({
    super.key,
    this.symbol = 'IBM',
  });

  @override
  State<StockChartScreen> createState() => _StockChartScreenState();
}

class _StockChartScreenState extends State<StockChartScreen> {
  late String _symbol;
  Timeframe _selectedTimeframe = Timeframe.oneMonth;
  late Future<List<StockPrice>> _pricesFuture;

  // Cached latest close price, used by the Trade FAB (outside the FutureBuilder).
  double? _latestPrice;

  @override
  void initState() {
    super.initState();
    _symbol = widget.symbol;
    _loadData();
  }

  void _loadData() {
    _pricesFuture = StockDataService.fetchStockPrices(
      _symbol,
      range: _selectedTimeframe.range,
      interval: _selectedTimeframe.interval,
    );
  }

  void _onTimeframeSelected(Timeframe tf) {
    setState(() {
      _selectedTimeframe = tf;
      _loadData();
    });
  }

  void _onSymbolSelected(String symbol) {
    setState(() {
      _symbol = symbol;
      _latestPrice = null; // reset until new data arrives
      _loadData();
    });
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
      _onSymbolSelected(selected);
    }
  }

  void _openTrade() {
    if (_latestPrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the price to load.')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuySellScreen(
          symbol: _symbol,
          currentPrice: _latestPrice!,
        ),
      ),
    );
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
                '$_symbol Stock Price',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
        // actions: const [
        //   BackToCustomerMenuButton(),
        //   SizedBox(width: 8),
        // ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 0,
        onTrade: _openTrade,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSearch,
        icon: const Icon(Icons.search),
        label: const Text('Stock'),
      ),
      body: Column(
        children: [
          _buildTimeframeSelector(),
          Expanded(
            child: FutureBuilder<List<StockPrice>>(
              future: _pricesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error loading data:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                }

                final prices = snapshot.data ?? [];
                if (prices.isEmpty) {
                  return const Center(child: Text('No data available'));
                }

                final chronological = prices.reversed.toList();
                final currentPrice = chronological.last.close;
                final startPrice = chronological.first.close;
                final change = currentPrice - startPrice;
                final changePercent =
                startPrice == 0 ? 0.0 : (change / startPrice) * 100;
                final isUp = change >= 0;

                // Cache the latest price for the Trade FAB without triggering
                // a rebuild loop (safe since it's a plain field write).
                if (_latestPrice != currentPrice) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _latestPrice = currentPrice);
                    }
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'RM${currentPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            children: [
                              Icon(
                                isUp
                                    ? Icons.arrow_drop_up
                                    : Icons.arrow_drop_down,
                                color: isUp ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              Text(
                                '${isUp ? '+' : ''}${change.toStringAsFixed(2)} '
                                    '(${isUp ? '+' : ''}${changePercent.toStringAsFixed(2)}%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isUp ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '  over ${_selectedTimeframe.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: CandlestickChart(
                          _buildChartData(chronological, currentPrice),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        children: Timeframe.values.map((tf) {
          final isSelected = tf == _selectedTimeframe;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(tf.label),
              selected: isSelected,
              onSelected: (_) => _onTimeframeSelected(tf),
            ),
          );
        }).toList(),
      ),
    );
  }

  CandlestickChartData _buildChartData(
      List<StockPrice> prices, double currentPrice) {
    final spots = <CandlestickSpot>[
      for (int i = 0; i < prices.length; i++)
        CandlestickSpot(
          x: i.toDouble(),
          open: prices[i].open,
          high: prices[i].high,
          low: prices[i].low,
          close: prices[i].close,
        ),
    ];

    final lows = prices.map((p) => p.low).toList();
    final highs = prices.map((p) => p.high).toList();
    var minY = lows.reduce((a, b) => a < b ? a : b);
    var maxY = highs.reduce((a, b) => a > b ? a : b);
    minY = minY < currentPrice ? minY : currentPrice;
    maxY = maxY > currentPrice ? maxY : currentPrice;
    final padding = (maxY - minY) * 0.1;
    final range = maxY - minY;

    return CandlestickChartData(
      candlestickSpots: spots,
      minY: minY - padding,
      maxY: maxY + padding,
      gridData: const FlGridData(show: true,
        drawHorizontalLine: true,
        drawVerticalLine: false,),
      borderData: FlBorderData(show: true),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 32,
            interval: (prices.length / 5).clamp(1, prices.length).toDouble(),
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= prices.length) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  prices[index].date.substring(5),
                  style: const TextStyle(fontSize: 10),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 48,
            getTitlesWidget: (value, meta) => Text(
              'RM${value.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ),
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(
            y1: currentPrice - range * 0.0015,
            y2: currentPrice + range * 0.0015,
            color: Colors.blue.withValues(alpha: 0.4),
          ),
        ],
      ),
      candlestickTouchData: CandlestickTouchData(
        touchTooltipData: CandlestickTouchTooltipData(
          getTooltipItems: (painter, touchedSpot, spotIndex) {
            final price = prices[spotIndex];
            return CandlestickTooltipItem(
              'RM${price.close.toStringAsFixed(2)}',
              textStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
              bottomMargin: 8,
              children: [
                TextSpan(
                  text: '\n${price.date}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class StockSearchSheet extends StatefulWidget {
  const StockSearchSheet({super.key});

  @override
  State<StockSearchSheet> createState() => _StockSearchSheetState();
}

class _StockSearchSheetState extends State<StockSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, String>> _filtered = kTopStocks;

  void _onSearchChanged(String query) {
    setState(() {
      final q = query.toLowerCase();
      _filtered = kTopStocks.where((stock) {
        return stock['symbol']!.toLowerCase().contains(q) ||
            stock['name']!.toLowerCase().contains(q);
      }).toList();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search by symbol or name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      _onSearchChanged('');
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _filtered.isEmpty
                    ? const Center(child: Text('No matches found'))
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _filtered.length,
                  itemBuilder: (context, index) {
                    final stock = _filtered[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(stock['symbol']![0]),
                      ),
                      title: Text(stock['symbol']!),
                      subtitle: Text(stock['name']!),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(context, stock['symbol']);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}