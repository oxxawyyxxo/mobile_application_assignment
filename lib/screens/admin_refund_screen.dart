import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRefundScreen extends StatefulWidget {
  const AdminRefundScreen({super.key});

  @override
  State<AdminRefundScreen> createState() => _AdminRefundScreenState();
}

class _AdminRefundScreenState extends State<AdminRefundScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  late Future<List<Map<String, dynamic>>> _pendingFuture;
  late Future<List<Map<String, dynamic>>> _historyFuture;

  static String _formatUtc8(DateTime utcTime) {
    final local = utcTime.toUtc().add(const Duration(hours: 8));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour < 12 ? 'AM' : 'PM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, '
        '$hour12:$minute $period (UTC+8)';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _pendingFuture = _fetchRequests(status: 'pending');
    _historyFuture = _fetchRequests(status: null);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchRequests({String? status}) async {
    var query = _supabase.from('refund_requests').select(
        'id, user_id, amount, status, reason, created_at, reviewed_at');

    if (status != null) {
      query = query.eq('status', status);
    } else {
      query = query.neq('status', 'pending');
    }

    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    setState(() {
      _pendingFuture = _fetchRequests(status: 'pending');
      _historyFuture = _fetchRequests(status: null);
    });
  }

  Future<void> _review(String requestId, bool approve) async {
    String? reason;

    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final ctrl = TextEditingController();
          return AlertDialog(
            title: const Text('Reason for Denial'),
            content: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Optional note for the user',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, ctrl.text),
                child: const Text('Deny'),
              ),
            ],
          );
        },
      );
      if (reason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Approve Refund'),
          content: const Text(
            'This will deduct the credit from the user\'s credit balance. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Approve'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    try {
      await _supabase.rpc('review_refund_request', params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_reason': reason,
      });

      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approve ? 'Refund approved.' : 'Refund denied.'),
          backgroundColor: approve ? colorScheme.primary : colorScheme.error,
        ),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: colorScheme.error),
      );
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
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
            ),
            const SizedBox(width: 20),
            Text(
              'Refund Requests',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.primary,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingList(),
          _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildPendingList() {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _pendingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)));
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 200),
                  child: Center(child: Text('No pending refund requests.')),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = requests[index];
              final id = r['id'] as String;
              final amount = (r['amount'] as num).toDouble();
              final createdAt = DateTime.parse(r['created_at'] as String);
              final userId = r['user_id'] as String;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RM ${amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('User: $userId',
                          style: const TextStyle(fontSize: 12)),
                      Text(
                        'Requested: ${_formatUtc8(createdAt)}',
                        style: TextStyle(
                            fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _review(id, false),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: colorScheme.error),
                              child: const Text('Deny'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _review(id, true),
                              style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.primary,
                                  foregroundColor: colorScheme.onPrimary),
                              child: const Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)));
          }

          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                Padding(
                  padding: EdgeInsets.only(top: 200),
                  child: Center(child: Text('No reviewed requests yet.')),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final r = requests[index];
              final amount = (r['amount'] as num).toDouble();
              final status = r['status'] as String;
              final reason = r['reason'] as String?;
              final reviewedAt = r['reviewed_at'] != null
                  ? DateTime.parse(r['reviewed_at'] as String)
                  : null;
              final isApproved = status == 'approved';

              return Card(
                child: ListTile(
                  leading: Icon(
                    isApproved ? Icons.check_circle : Icons.cancel,
                    color: isApproved ? colorScheme.primary : colorScheme.error,
                  ),
                  title: Text('RM ${amount.toStringAsFixed(2)} · ${status[0].toUpperCase()}${status.substring(1)}'),
                  subtitle: Text(
                    [
                      if (reviewedAt != null)
                        'Reviewed: ${_formatUtc8(reviewedAt)}',
                      if (reason != null && reason.isNotEmpty) 'Note: $reason',
                    ].join('\n'),
                  ),
                  isThreeLine: reason != null && reason.isNotEmpty,
                ),
              );
            },
          );
        },
      ),
    );
  }
}