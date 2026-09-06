import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_price_model.dart';

class StockDataService {
  static const String _proxyBase = 'https://yahoo-proxy.myapp5435-proxy.workers.dev';
  static const String _yahooBase = 'https://query1.finance.yahoo.com/v8/finance/chart';

  static double? _cachedFxRate;

  static Future<double> _fetchUsdToMyrRate() async {
    if (_cachedFxRate != null) return _cachedFxRate!;

    final yahooUrl = '$_yahooBase/USDMYR=X?range=1d&interval=1d';
    final url = Uri.parse('$_proxyBase/?url=${Uri.encodeComponent(yahooUrl)}');

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch USD/MYR rate: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final result = data['chart']?['result']?[0];
    if (result == null) {
      throw Exception('Unexpected FX response format');
    }

    final rate = (result['meta']?['regularMarketPrice'] as num?)?.toDouble();
    if (rate == null) {
      throw Exception('Could not parse USD/MYR rate');
    }

    _cachedFxRate = rate;
    return rate;
  }

  static Future<List<StockPrice>> fetchStockPrices(
      String symbol, {
        String range = '1mo',
        String interval = '1d',
        bool convertToMyr = true,
      }) async {
    final yahooUrl = '$_yahooBase/$symbol?range=$range&interval=$interval';
    final url = Uri.parse('$_proxyBase/?url=${Uri.encodeComponent(yahooUrl)}');
    print('Fetching URL: $url');

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to load data for $symbol: ${response.statusCode}');
      }

      final data = jsonDecode(response.body);

      if (data['chart']?['error'] != null) {
        throw Exception('Invalid symbol: $symbol');
      }

      final result = data['chart']?['result']?[0];
      if (result == null) {
        throw Exception('Unexpected response format for $symbol');
      }

      final List<dynamic> timestamps = result['timestamp'] ?? [];
      final quote = result['indicators']?['quote']?[0];
      if (quote == null || timestamps.isEmpty) {
        throw Exception('No price data available for $symbol');
      }

      final List<dynamic> opens = quote['open'] ?? [];
      final List<dynamic> highs = quote['high'] ?? [];
      final List<dynamic> lows = quote['low'] ?? [];
      final List<dynamic> closes = quote['close'] ?? [];
      final List<dynamic> volumes = quote['volume'] ?? [];

      final fxRate = convertToMyr ? await _fetchUsdToMyrRate() : 1.0;
      final bool intraday = interval.endsWith('m') || interval.endsWith('h');

      final List<StockPrice> prices = [];
      for (int i = 0; i < timestamps.length; i++) {
        if (opens[i] == null ||
            highs[i] == null ||
            lows[i] == null ||
            closes[i] == null) {
          continue;
        }

        prices.add(StockPrice.fromYahoo(
          timestamp: timestamps[i] as int,
          open: (opens[i] as num).toDouble(),
          high: (highs[i] as num).toDouble(),
          low: (lows[i] as num).toDouble(),
          close: (closes[i] as num).toDouble(),
          volume: (volumes[i] as num?)?.toInt() ?? 0,
          fxRate: fxRate,
          intraday: intraday,
        ));
      }

      prices.sort((a, b) => b.date.compareTo(a.date));
      return prices;
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, List<StockPrice>>> fetchMultipleStockPrices(
      List<String> symbols, {
        String range = '1mo',
        String interval = '1d',
      }) async {
    final Map<String, List<StockPrice>> results = {};

    final futures = symbols.map((symbol) async {
      try {
        final prices = await fetchStockPrices(
          symbol,
          range: range,
          interval: interval,
        );
        results[symbol] = prices;
      } catch (e) {
        results[symbol] = [];
        print('Error fetching $symbol: $e');
      }
    });

    await Future.wait(futures);
    return results;
  }
}