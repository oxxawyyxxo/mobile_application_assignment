import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/fuel_price_model.dart';

class LocalDbService {
  static Database? _db;

  static Future<Database> get database async{
    if (_db != null){
      return _db!;
    };

    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async{
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String path = join(await getDatabasesPath(), 'petrol_app.db');

    return await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async{
        await db.execute('DROP TABLE IF EXISTS cached_fuel_prices');
        await db.execute('DROP TABLE IF EXISTS cached_transactions');
        await _createTables(db);
      }
    );
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE cached_fuel_prices (
        date TEXT PRIMARY KEY,
        series_type TEXT,
        ron95 REAL,
        ron97 REAL,
        diesel REAL,
        diesel_eastmsia REAL,
        ron95_budi95 REAL,
        ron95_skps REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE cached_transactions (
        id TEXT PRIMARY KEY,
        fuel_type TEXT,
        litres REAL,
        total_price REAL,
        created_at TEXT
      )
    ''');
  }

  static Future<void> cacheFuelPrices(List<FuelPrice> prices) async {
    final db = await database;
    Batch batch = db.batch();

    for (var price in prices){
      batch.insert(
        'cached_fuel_prices',
        price.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
    await batch.commit();
  }

  static Future<List<FuelPrice>> getCachedFuelPrices({int? limit}) async {
    final db = await database;
    final res = await db.query(
      'cached_fuel_prices',
      where: 'series_type = ?',
      whereArgs: ['level'],
      orderBy: 'date ASC',
      limit: limit,
    );
    return res.map((e) => FuelPrice.fromJson(e)).toList();
  }

  static Future<void> saveLocalUserPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('user_points', points);
  }

  static Future<int> getLocalUserPoints() async{
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_points') ?? 0;
  }
}