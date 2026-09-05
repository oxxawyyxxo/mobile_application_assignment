import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fuel_price_model.dart';
import 'local_db_service.dart';

class GovDataService {
  static const String _baseUrl = 'https://api.data.gov.my/data-catalogue';
  static const String _datasetId = 'fuelprice';

  static Future<List<FuelPrice>> fetchFuelPrices({int limit = 15}) async {
    final Uri url = Uri.parse('$_baseUrl?id=$_datasetId&limit=$limit');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(response.body);
        List<FuelPrice> prices = jsonList
            .map((item) => FuelPrice.fromJson(item))
            .where((item) => item.seriesType == 'level')
            .toList();

        await LocalDbService.cacheFuelPrices(prices);
        return prices;
      } else {
        print('API Error Code: ${response.statusCode}');
      }
    } catch (e) {
      print('Network exception: $e. Falling back to local cache.');
    }

    return await LocalDbService.getCachedFuelPrices();
  }
}