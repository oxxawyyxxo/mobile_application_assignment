import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  final _supabase = Supabase.instance.client;
  final Map<String, String> _userNamesCache = {};

  Future<String> _getUserFullName(String userId) async {
    if (_userNamesCache.containsKey(userId)) {
      return _userNamesCache[userId]!;
    }
    try {
      final res = await _supabase
          .from('user_profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();

      final fullName = res?['full_name'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        _userNamesCache[userId] = fullName;
        return fullName;
      }
    } catch (_) {}
    return userId;
  }

  String _formatDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(rawDate).toLocal();
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final hour12 = parsed.hour % 12 == 0 ? 12 : parsed.hour % 12;
      final period = parsed.hour < 12 ? 'AM' : 'PM';
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}, $hour12:$minute $period';
    } catch (_) {
      return rawDate;
    }
  }

  final Map<String, String> _contentCache = {};

  Future<String> _getReportedContent(String? postId, String? commentId) async {
    final cacheKey = commentId != null ? 'comment_$commentId' : 'post_$postId';
    if (_contentCache.containsKey(cacheKey)) {
      return _contentCache[cacheKey]!;
    }

    try {
      if (commentId != null) {
        final res = await _supabase
            .from('news_comments')
            .select('content')
            .eq('id', commentId)
            .maybeSingle();
        final content = res?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          final result = 'Comment: "$content"';
          _contentCache[cacheKey] = result;
          return result;
        }
      } else if (postId != null) {
        final res = await _supabase
            .from('news_posts')
            .select('content')
            .eq('id', postId)
            .maybeSingle();
        final content = res?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          final result = 'Post: "$content"';
          _contentCache[cacheKey] = result;
          return result;
        }
      }
    } catch (_) {}

    return commentId != null ? 'Comment ID: $commentId' : 'Post ID: $postId';
  }


  Future<void> _removeContent(String? postId, String? commentId) async {
    if (postId != null) {
      await _supabase.from('news_posts').update({'status': 'admin_removed'}).eq('id', postId);
      await _supabase.from('news_reports').delete().eq('post_id', postId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post removed')));
    } else if (commentId != null) {
      await _supabase.from('news_comments').update({'status': 'admin_removed'}).eq('id', commentId);
      await _supabase.from('news_reports').delete().eq('comment_id', commentId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment removed')));
    }
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
                subtitle: FutureBuilder<String>(
                  future: _getUserFullName(post['author_id']),
                  builder: (context, nameSnapshot) {
                    final authorName = nameSnapshot.data ?? 'Loading...';
                    return Text(
                      isRemoved ? 'Author: $authorName (Status: Removed by Admin)' : 'Author: $authorName',
                      style: TextStyle(color: isRemoved ? colorScheme.error : colorScheme.onSurfaceVariant),
                    );
                  },
                ),
                trailing: isRemoved
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.delete, color: colorScheme.error),
                            tooltip: 'Remove Post',
                            onPressed: () {
                              setState(() {
                                _removeContent(post['id'], null);
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(Icons.block, color: colorScheme.tertiary),
                            tooltip: 'Ban Author',
                            onPressed: () {
                              setState(() {
                                _banUser(post['author_id']);
                              });
                            },
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
                title: FutureBuilder<String>(
                  future: _getReportedContent(report['post_id'], report['comment_id']),
                  builder: (context, contentSnapshot) {
                    final content = contentSnapshot.data ?? 'Loading content...';
                    return Text(content);
                  },
                ),
                subtitle: FutureBuilder<String>(
                  future: _getUserFullName(report['reporter_id']),
                  builder: (context, nameSnapshot) {
                    final reporterName = nameSnapshot.data ?? 'Loading...';
                    return Text('Reason: ${report['reason']}\nReported by: $reporterName');
                  },
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _ignoreReport(report['id']);
                        });
                      },
                      child: Text('Ignore', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete, color: colorScheme.error),
                      tooltip: 'Remove Offending Content',
                      onPressed: () {
                        setState(() {
                          _removeContent(report['post_id'], report['comment_id']);
                        });
                      },
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
                title: FutureBuilder<String>(
                  future: _getUserFullName(userId),
                  builder: (context, nameSnapshot) {
                    final userName = nameSnapshot.data ?? 'Loading...';
                    return Text('User: $userName');
                  },
                ),
                subtitle: Text('Banned on: ${_formatDate(entry['created_at']?.toString())}'),
                trailing: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                  ),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: const Text('Unban'),
                  onPressed: () {
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