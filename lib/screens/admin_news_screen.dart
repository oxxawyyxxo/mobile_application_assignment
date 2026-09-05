import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final _supabase = Supabase.instance.client;

  // --- ACTIONS ---

  Future<void> _removePost(String postId) async {
    await _supabase.from('news_posts').update({'status': 'admin_removed'}).eq('id', postId);
    await _supabase.from('news_reports').delete().eq('post_id', postId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post removed')));
  }

  Future<void> _banUser(String userId) async {
    await _supabase.from('banned_users').insert({
      'user_id': userId,
      'banned_by': _supabase.auth.currentUser!.id,
    });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User banned')));
  }

  Future<void> _unbanUser(String userId) async {
    await _supabase.from('banned_users').delete().eq('user_id', userId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unbanned')));
  }

  Future<void> _ignoreReport(String reportId) async {
    await _supabase.from('news_reports').delete().eq('id', reportId);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report dismissed')));
  }

  // Resets all transactions, posts, and trades for a specific user except profile
  Future<void> _resetUserData(String userId) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset User Data?'),
        content: Text('This will permanently delete all posts, reports, and trade history for User: $userId. Profile information will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Delete all user posts
      await _supabase.from('news_posts').delete().eq('author_id', userId);
      // 2. Delete all user reports
      await _supabase.from('news_reports').delete().eq('reporter_id', userId);
      // 3. Delete user trades / portfolio transactions (adjust table names if different)
      await _supabase.from('trades').delete().eq('user_id', userId);
      await _supabase.from('transactions').delete().eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User transactions & posts wiped successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resetting user data: $e'), backgroundColor: colorScheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
                'Admin Dashboard',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            indicatorColor: colorScheme.primary,
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            tabs: const [
              Tab(icon: Icon(Icons.list), text: 'Posts'),
              Tab(icon: Icon(Icons.flag), text: 'Reports'),
              Tab(icon: Icon(Icons.block), text: 'Banned'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPostsTab(),
            _buildReportsTab(),
            _buildBannedUsersTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('news_posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final posts = snapshot.data!;
        if (posts.isEmpty) return const Center(child: Text('No posts yet.'));

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final isRemoved = post['status'] == 'admin_removed';

            return Card(
              margin: const EdgeInsets.all(8.0),
              color: isRemoved ? colorScheme.surfaceContainerHigh : colorScheme.surface,
              child: ListTile(
                title: Text(post['content']),
                subtitle: Text(
                  isRemoved ? 'Status: Removed by Admin' : 'Author ID: ${post['author_id']}',
                  style: TextStyle(color: isRemoved ? colorScheme.error : colorScheme.onSurfaceVariant),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRemoved) ...[
                      IconButton(
                        icon: Icon(Icons.delete, color: colorScheme.error),
                        tooltip: 'Remove Post',
                        onPressed: () => _removePost(post['id']),
                      ),
                      IconButton(
                        icon: Icon(Icons.block, color: colorScheme.tertiary),
                        tooltip: 'Ban Author',
                        onPressed: () => _banUser(post['author_id']),
                      ),
                    ],
                    IconButton(
                      icon: Icon(Icons.restore_from_trash, color: colorScheme.primary),
                      tooltip: 'Reset All Data for User',
                      onPressed: () => _resetUserData(post['author_id']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReportsTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('news_reports').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reports = snapshot.data!;
        if (reports.isEmpty) return const Center(child: Text('No reports yet.'));

        return ListView.builder(
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final report = reports[index];
            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: Icon(Icons.warning, color: colorScheme.tertiary),
                title: Text('Reported Post ID: ${report['post_id']}'),
                subtitle: Text('Reason: ${report['reason']}\nReported by: ${report['reporter_id']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _ignoreReport(report['id']),
                      child: Text('Ignore', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: colorScheme.error),
                      tooltip: 'Remove Offending Post',
                      onPressed: () => _removePost(report['post_id']),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBannedUsersTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('banned_users').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: colorScheme.error)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final bannedList = snapshot.data!;
        if (bannedList.isEmpty) return const Center(child: Text('No banned users.'));

        return ListView.builder(
          itemCount: bannedList.length,
          itemBuilder: (context, index) {
            final entry = bannedList[index];
            final userId = entry['user_id'];

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: ListTile(
                leading: Icon(Icons.person_off, color: colorScheme.error),
                title: Text('User ID: $userId'),
                subtitle: Text('Banned on: ${entry['created_at'] ?? 'N/A'}'),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Unban'),
                  onPressed: () {
                    _unbanUser(userId);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}