import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/fuel_price_model.dart';
import '../services/gov_data_service.dart';

class PetrolChartScreen extends StatefulWidget {
  const PetrolChartScreen({super.key});

  @override
  State<PetrolChartScreen> createState() => _PetrolChartScreenState();
}

class _PetrolChartScreenState extends State<PetrolChartScreen> {
  late Future<List<FuelPrice>> _priceFuture;

  // Interactive Filter States
  final Set<String> _selectedFuels = {'RON95', 'RON97', 'Diesel'};
  String _selectedTimeframe = 'ALL'; // Options: '1M', '3M', '6M', 'ALL'

  @override
  void initState() {
    super.initState();
    _priceFuture = GovDataService.fetchFuelPrices(limit: 52); // Fetch up to 1 year of data
  }

  // Filter dataset by timeframe
  List<FuelPrice> _filterByTimeframe(List<FuelPrice> sortedPrices) {
    if (_selectedTimeframe == 'ALL' || sortedPrices.isEmpty) return sortedPrices;

    final DateTime? latestDate = DateTime.tryParse(sortedPrices.last.date);
    if (latestDate == null) return sortedPrices;

    int days = 365;
    if (_selectedTimeframe == '1M') days = 30;
    if (_selectedTimeframe == '3M') days = 90;
    if (_selectedTimeframe == '6M') days = 180;

    final cutoff = latestDate.subtract(Duration(days: days));
    return sortedPrices.where((p) {
      final d = DateTime.tryParse(p.date);
      return d != null && d.isAfter(cutoff);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            children: [
              // Back button
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
              ),

              const SizedBox(width: 20),

              // Heading
              Expanded(
                child: Text(
                  'Petrol Analytics',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.show_chart), text: 'Interactive Graph'),
              Tab(icon: Icon(Icons.table_chart), text: 'Data Table'),
            ],
          ),
        ),
        body: FutureBuilder<List<FuelPrice>>(
          future: _priceFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No price data available.'));
            }

            final List<FuelPrice> sortedPrices = List.from(snapshot.data!)
              ..sort((a, b) => a.date.compareTo(b.date));

            final List<FuelPrice> filteredPrices = _filterByTimeframe(sortedPrices);
            final latest = sortedPrices.last;
            final previous = sortedPrices.length > 1 ? sortedPrices[sortedPrices.length - 2] : null;

            return TabBarView(
              children: [
                _buildInteractiveGraphTab(filteredPrices, latest, previous),
                _buildDataTableTab(sortedPrices.reversed.toList()),
              ],
            );
          },
        ),
      ),
    );
  }

  // ==================== INTERACTIVE GRAPH TAB ====================
  Widget _buildInteractiveGraphTab(List<FuelPrice> prices, FuelPrice latest, FuelPrice? previous) {
    // Calculate dynamic Y-axis min and max based on active filters with fixed 0.1 step size
    double rawMin = double.infinity;
    double rawMax = double.negativeInfinity;

    for (var p in prices) {
      if (_selectedFuels.contains('RON95')) {
        rawMin = min(rawMin, p.ron95);
        rawMax = max(rawMax, p.ron95);
      }
      if (_selectedFuels.contains('RON97')) {
        rawMin = min(rawMin, p.ron97);
        rawMax = max(rawMax, p.ron97);
      }
      if (_selectedFuels.contains('Diesel')) {
        rawMin = min(rawMin, p.diesel);
        rawMax = max(rawMax, p.diesel);
      }
    }

    const double yInterval = 0.1;
    double minY;
    double maxY;

    if (rawMin == double.infinity) {
      minY = 1.0;
      maxY = 5.0;
    } else {
      minY = ((rawMin - 0.02) / yInterval).floorToDouble() * yInterval;
      if (minY < 0) minY = 0.0;
      maxY = ((rawMax + 0.02) / yInterval).ceilToDouble() * yInterval;

      // Round to 1 decimal place to eliminate floating point inaccuracies
      minY = (minY * 10).round() / 10.0;
      maxY = (maxY * 10).round() / 10.0;

      if (minY >= maxY) {
        maxY = (minY + yInterval * 2);
        maxY = (maxY * 10).round() / 10.0;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Timeframe Filter (Segmented Button / Choice Chips)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                children: ['1M', '3M', '6M', 'ALL'].map((tf) {
                  final isSelected = _selectedTimeframe == tf;
                  return ChoiceChip(
                    label: Text(tf, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black)),
                    selected: isSelected,
                    selectedColor: Colors.blue,
                    checkmarkColor: Colors.white,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedTimeframe = tf);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Interactive Fuel Series Toggles (Multi-Select Filter Chips)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  _buildFuelFilterChip('RON95', Colors.blue),
                  _buildFuelFilterChip('RON97', Colors.green),
                  _buildFuelFilterChip('Diesel', Colors.orange),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 3. Interactive Line Chart
          SizedBox(
            height: 320,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                ),
                // Touch interaction & Tooltip configuration
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey.shade900,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.asMap().entries.map((entry) {
                        final spotIndexInList = entry.key;
                        final spot = entry.value;
                        final fuelName = spot.bar.color == Colors.blue
                            ? 'RON95'
                            : spot.bar.color == Colors.green
                            ? 'RON97'
                            : 'Diesel';
                        final index = spot.x.round().clamp(0, prices.length - 1);
                        final dateStr = prices[index].date;
                        final text = spotIndexInList == 0
                            ? '$dateStr\n$fuelName: RM ${spot.y.toStringAsFixed(2)}'
                            : '$fuelName: RM ${spot.y.toStringAsFixed(2)}';
                        return LineTooltipItem(
                          text,
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: yInterval,
                      reservedSize: 45,
                      getTitlesWidget: (val, meta) => Text(
                        'RM ${val.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (prices.length / 6).ceil().toDouble().clamp(1.0, double.infinity),
                      getTitlesWidget: (value, meta) {
                        int index = value.round();
                        if ((value - index).abs() > 0.01) {
                          return const SizedBox.shrink();
                        }
                        if (index >= 0 && index < prices.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Text(
                              prices[index].date.substring(5),
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  if (_selectedFuels.contains('RON95'))
                    _buildChartBarData(prices, (p) => p.ron95, Colors.blue),
                  if (_selectedFuels.contains('RON97'))
                    _buildChartBarData(prices, (p) => p.ron97, Colors.green),
                  if (_selectedFuels.contains('Diesel'))
                    _buildChartBarData(prices, (p) => p.diesel, Colors.orange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Latest Price Cards Summary
          const Text('Latest Price Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildPriceCard('RON95', latest.ron95, previous?.ron95, Colors.blue),
                _buildPriceCard('RON97', latest.ron97, previous?.ron97, Colors.green),
                _buildPriceCard('Diesel', latest.diesel, previous?.diesel, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HELPER BUILDERS ====================

  FilterChip _buildFuelFilterChip(String label, Color color) {
    final isSelected = _selectedFuels.contains(label);
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : color)),
      selected: isSelected,
      selectedColor: color,
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedFuels.add(label);
          } else {
            // Prevent deselecting all items
            if (_selectedFuels.length > 1) _selectedFuels.remove(label);
          }
        });
      },
    );
  }

  LineChartBarData _buildChartBarData(List<FuelPrice> prices, double Function(FuelPrice) getPrice, Color color) {
    return LineChartBarData(
      spots: prices.asMap().entries.map((e) => FlSpot(e.key.toDouble(), getPrice(e.value))).toList(),
      color: color,
      barWidth: 3,
      isCurved: true,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
    );
  }

  Widget _buildPriceCard(String title, double currentPrice, double? previousPrice, Color accentColor) {
    double diff = previousPrice != null ? currentPrice - previousPrice : 0.0;
    bool isLower = diff < 0;
    bool isUnchanged = diff == 0;
    Color indicatorColor = isUnchanged ? Colors.grey : (isLower ? Colors.green.shade700 : Colors.red.shade700);

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: accentColor)),
          Text('RM ${currentPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Row(
            children: [
              Icon(isUnchanged ? Icons.remove : (isLower ? Icons.arrow_downward : Icons.arrow_upward), color: indicatorColor, size: 14),
              const SizedBox(width: 4),
              Text(isUnchanged ? 'Flat' : '${diff.abs().toStringAsFixed(2)}/L', style: TextStyle(color: indicatorColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataTableTab(List<FuelPrice> reversePrices) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('RON95', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('RON97', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Diesel', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: reversePrices.map((item) {
            return DataRow(
              cells: [
                DataCell(Text(item.date)),
                DataCell(Text('RM ${item.ron95.toStringAsFixed(2)}')),
                DataCell(Text('RM ${item.ron97.toStringAsFixed(2)}')),
                DataCell(Text('RM ${item.diesel.toStringAsFixed(2)}')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}