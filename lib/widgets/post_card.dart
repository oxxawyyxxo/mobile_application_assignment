import 'package:flutter/material.dart';
import '../models/news_post.dart';
import '../services/news_service.dart';

class PostCard extends StatelessWidget {
  final NewsPost post;
  final NewsService newsService;

  const PostCard({super.key, required this.post, required this.newsService});

  void _showEditDialog(BuildContext context) {
    final TextEditingController editCtrl = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Post'),
        content: TextField(
          controller: editCtrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (editCtrl.text.trim().isNotEmpty) {
                newsService.editPost(post.id, editCtrl.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post updated successfully')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMine = post.authorId == newsService.currentUserId;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(post.isAnonymous ? 'Anonymous' : 'User ID: ${post.authorId.substring(0, 5)}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'delete') {
                  await newsService.deletePost(post.id);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
                }
                if (value == 'edit') _showEditDialog(context);
                if (value == 'report') {
                  await newsService.reportPost(post.id);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent to admin for verify')));
                }
              },
              itemBuilder: (context) => [
                if (isMine && post.status == 'active') const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (isMine && post.status == 'active') const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (!isMine && post.status == 'active') const PopupMenuItem(value: 'report', child: Text('Report')),
              ],
            ),
          ),
          if (post.status == 'user_deleted')
            const Padding(padding: EdgeInsets.all(16.0), child: Text('This post was deleted by the author', style: TextStyle(color: Colors.grey)))
          else if (post.status == 'admin_removed')
            const Padding(padding: EdgeInsets.all(16.0), child: Text('This post was removed by an admin', style: TextStyle(color: Colors.red)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.imageUrl != null) Image.network(post.imageUrl!),
                Padding(padding: const EdgeInsets.all(12.0), child: Text(post.content)),
                if (post.isEdited) const Padding(padding: EdgeInsets.only(left: 12.0, bottom: 8.0), child: Text('(Edited)', style: TextStyle(color: Colors.grey, fontSize: 12))),
              ],
            ),
        ],
      ),
    );
  }
}