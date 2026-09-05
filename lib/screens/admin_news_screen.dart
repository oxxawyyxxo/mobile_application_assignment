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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset User Data?'),
        content: Text('This will permanently delete all posts, reports, and trade history for User: $userId. Profile information will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset Everything', style: TextStyle(color: Colors.white)),
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
          SnackBar(content: Text('Error resetting user data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.list), text: 'Posts'),
              Tab(icon: Icon(Icons.flag), text: 'Reports'),
              Tab(icon: Icon(Icons.block), text: 'Banned Users'),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('news_posts').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
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
              color: isRemoved ? Colors.grey.shade200 : Colors.white,
              child: ListTile(
                title: Text(post['content']),
                subtitle: Text(
                  isRemoved ? 'Status: Removed by Admin' : 'Author ID: ${post['author_id']}',
                  style: TextStyle(color: isRemoved ? Colors.red : Colors.grey),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isRemoved) ...[
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Remove Post',
                        onPressed: () => _removePost(post['id']),
                      ),
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.orange),
                        tooltip: 'Ban Author',
                        onPressed: () => _banUser(post['author_id']),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.restore_from_trash, color: Colors.purple),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('news_reports').stream(primaryKey: ['id']).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
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
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: Text('Reported Post ID: ${report['post_id']}'),
                subtitle: Text('Reason: ${report['reason']}\nReported by: ${report['reporter_id']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _ignoreReport(report['id']),
                      child: const Text('Ignore', style: TextStyle(color: Colors.grey)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
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
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from('banned_users').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
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
                leading: const Icon(Icons.person_off, color: Colors.red),
                title: Text('User ID: $userId'),
                subtitle: Text('Banned on: ${entry['created_at'] ?? 'N/A'}'),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  label: const Text('Unban', style: TextStyle(color: Colors.white)),
                  onPressed: (){
                    setState(() {
                      _unbanUser(userId);
                    });
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