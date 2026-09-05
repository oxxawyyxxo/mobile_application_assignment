import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/screens/admin_news_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile_application_assignment/auth/login_screen.dart';

import '../screens/admin_petrol_screen.dart';
import '../screens/admin_refund_screen.dart';

class StaffMenu extends StatefulWidget {
  final String name;

  const StaffMenu({super.key, required this.name});

  @override
  State<StaffMenu> createState() => _StaffMenuState();
}

class _StaffMenuState extends State<StaffMenu> {
  final _supabase = Supabase.instance.client;

  Future<void> _logout() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  // --- GLOBAL SYSTEM RESET ---
  Future<void> _resetAllSystemData() async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ DANGER: Reset Entire System Data?'),
        content: const Text(
          'This will permanently delete all records in:\n\n'
              '• News (posts, reports, images)\n'
              '• Trades & Portfolios\n'
              '• Transactions & Topups\n'
              '• Fuel & Refunds\n\n'
              'User Profiles and Banned Users will NOT be deleted. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wipe System Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      try {
        final files = await _supabase.storage.from('news_images').list();
        if (files.isNotEmpty) {
          final fileNames = files.map((f) => f.name).toList();
          await _supabase.storage.from('news_images').remove(fileNames);
        }
      } catch (e) {
        debugPrint('Warning: Failed to clear storage bucket or it was empty: $e');
      }

      final tablesToClear = [
        'news_reports',
        'news_posts',
        'portfolio_holdings',
        'refund_requests',
        'stock_trades',
        'topup_transactions',
        'transactions'
      ];

      // 3. Loop and delete
      for (String table in tablesToClear) {
        try {
          await _supabase.from(table).delete().neq('id', '00000000-0000-0000-0000-000000000000');
        } catch (e) {
          debugPrint('Warning: Failed to clear table $table: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('System records and images cleared! Profiles & bans preserved.'),
            backgroundColor: colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Critical error resetting system data: $e'), backgroundColor: colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
              child: Icon(
                Icons.badge_outlined,
                size: 28,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 20),
            Text(
              'Staff Dashboard',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Hi, Staff ${widget.name}.',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.local_gas_station, color: colorScheme.onPrimaryContainer, size: 28),
              ),
              title: const Text(
                'Manage Fuel Inventory',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: const Text('Update petrol stock volumes & availability'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPetrolScreen()),
                );
              },
            ),
          ),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.request_quote, color: colorScheme.onPrimaryContainer, size: 28),
              ),
              title: const Text(
                'Refund Requests',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: const Text('Approve/Deny Refund'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminRefundScreen()),
                );
              },
            ),
          ),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: colorScheme.primaryContainer,
                child: Icon(Icons.admin_panel_settings, color: colorScheme.onPrimaryContainer, size: 28),
              ),
              title: const Text(
                'Moderate News Community',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: const Text('Review reports and ban users'),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminNewsScreen()),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: colorScheme.error, width: 1.5),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                radius: 25,
                backgroundColor: colorScheme.errorContainer,
                child: Icon(Icons.delete_forever, color: colorScheme.onErrorContainer, size: 28),
              ),
              title: Text(
                'Reset System Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.error),
              ),
              subtitle: const Text('Wipe all records except profiles & bans'),
              trailing: Icon(Icons.warning, color: colorScheme.error),
              onTap: _resetAllSystemData,
            ),
          ),

          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}