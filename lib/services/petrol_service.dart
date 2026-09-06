import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db_service.dart';

class PetrolService {
  final _supabase = Supabase.instance.client;

  Future<void> updateFuelAvailability({
    required String fuelType,
    required double stockLitres,
    required bool isAvailable,
  }) async {
    await _supabase
        .from('fuel_inventory')
        .update({
      'stock_litres': stockLitres,
      'is_available': isAvailable,
    })
        .eq('fuel_type', fuelType);
  }

  Future<String?> buyPetrol({
    required String fuelType,
    required double requestedLitres,
    required bool redeemPoints,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return 'User not authenticated.';

    final fuelData = await _supabase
        .from('fuel_inventory')
        .select()
        .eq('fuel_type', fuelType)
        .single();

    final profileData = await _supabase
        .from('user_profiles')
        .select()
        .eq('id', user.id)
        .single();

    bool isAvailable = fuelData['is_available'];
    double currentStock = (fuelData['stock_litres'] as num).toDouble();
    double pricePerLitre = (fuelData['price'] as num).toDouble();
    int currentPoints = profileData['points'] ?? 0;

    if (!isAvailable || currentStock < requestedLitres) {
      return 'Purchase Denied: Insufficient fuel available.';
    }

    double rawTotal = requestedLitres * pricePerLitre;
    int pointsToRedeem = 0;
    double discount = 0.0;

    if (redeemPoints && currentPoints >= 100) {
      pointsToRedeem = (currentPoints / 100).floor() * 100;
      discount = pointsToRedeem / 100.0;
      if (discount > rawTotal) {
        discount = rawTotal;
        pointsToRedeem = (discount * 100).toInt();
      }
    }

    double finalTotal = rawTotal - discount;
    int pointsEarned = finalTotal.floor();

    final newStock = currentStock - requestedLitres;
    final updatedPoints = currentPoints - pointsToRedeem + pointsEarned;

    await _supabase.from('fuel_inventory').update({'stock_litres': newStock}).eq('fuel_type', fuelType);

    await _supabase.from('user_profiles').update({'points': updatedPoints}).eq('id', user.id);

    final txResponse = await _supabase.from('transactions').insert({
      'user_id': user.id,
      'fuel_type': fuelType,
      'litres': requestedLitres,
      'total_price': finalTotal,
      'points_earned': pointsEarned,
      'points_redeemed': pointsToRedeem,
    }).select().single();

    await LocalDbService.saveLocalUserPoints(updatedPoints);

    final db = await LocalDbService.database;
    await db.insert('cached_transactions', {
      'id': txResponse['id'],
      'fuel_type': fuelType,
      'litres': requestedLitres,
      'total_price': finalTotal,
      'created_at': DateTime.now().toIso8601String(),
    });

    return null;
  }
}