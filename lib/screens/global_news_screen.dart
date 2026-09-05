import 'package:flutter/material.dart';
import '../models/news_post.dart';
import '../models/official_news.dart';
import '../services/news_service.dart';
import '../widgets/post_card.dart';
import '../widgets/post_input_widget.dart';

class GlobalNewsScreen extends StatefulWidget {
  const GlobalNewsScreen({super.key});

  @override
  State<GlobalNewsScreen> createState() => _GlobalNewsScreenState();
}

class _GlobalNewsScreenState extends State<GlobalNewsScreen> {
  final NewsService _newsService = NewsService();
  bool _isBanned = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    final banned = await _newsService.checkIfBanned();
    if (mounted) {
      setState(() {
        _isBanned = banned;
        _isLoading = false;
      });
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, {TabBar? bottom}) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
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

          Expanded(
            child: Text(
              'Global News',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_isBanned) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: Text('You are banned from accessing this feature.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: _buildAppBar(
          context,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.announcement), text: 'Official News'),
              Tab(icon: Icon(Icons.people), text: 'Community'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOfficialNewsTab(),
            _buildCommunityTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOfficialNewsTab() {
    return FutureBuilder<List<OfficialNews>>(
      future: _newsService.getOfficialNews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No official news available.'));
        }

        final newsList = snapshot.data!;
        return ListView.separated(
          padding: const EdgeInsets.all(8.0),
          itemCount: newsList.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final news = newsList[index];
            return ListTile(
              title: Text(news.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    news.description.replaceAll(RegExp(r'<[^>]*>'), ''), // Strip HTML tags
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(news.pubDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              onTap: () {
                // Implement URL launching here if you want users to read the full article
              },
            );
          },
        );
      },
    );
  }

  Widget _buildCommunityTab() {
    return Column(
      children: [
        PostInputWidget(newsService: _newsService),
        Expanded(
          child: StreamBuilder<List<NewsPost>>(
            stream: _newsService.getPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text('No community posts yet. Be the first!'));
              }

              final posts = snapshot.data!;
              return ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  return PostCard(post: posts[index], newsService: _newsService);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}