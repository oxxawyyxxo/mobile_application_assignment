import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/auth/login_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/user_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await Supabase.initialize(
    url: 'https://rejdgrokuxyeedmkusyi.supabase.co',
    anonKey: 'sb_publishable_HH9MCbanXl7hinYWI8R5Cw_4hgdLOMU',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Petrol, Finance and Economy App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    );
  }
}

class AuthSeeder {
  static final _supabase = Supabase.instance.client;

  static final List<AppUser> mockUserDatabase = [
    AppUser(username: 'admin@gmail.com', fullName: 'Booi Ah Heng', password: 'Admin12345@', role: 'Staff'),
    AppUser(username: 'user@gmail.com', fullName: 'Ger Ah Heng', password: 'User12345@', role: 'User')
  ];

  static Future<void> initializeMockUsers() async {
    for (var user in mockUserDatabase) {
      try {
        final AuthResponse res = await _supabase.auth.signUp(
          email: user.username,
          password: user.password,
        );

        final String? userId = res.user?.id;

        if (userId != null) {
          await _supabase.from('user_profiles').upsert({
            'id': userId,
            'full_name': user.fullName,
            'role': user.role,
            'points': user.role == 'User' ? 500 : 0,
          });
          print('Successfully created: ${user.username}');
        }
      } catch (e) {
        print('Failed to create ${user.username}: $e (They might already exist)');
      }
    }
  }
}