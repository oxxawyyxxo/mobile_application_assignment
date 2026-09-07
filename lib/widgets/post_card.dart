import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/news_post.dart';
import '../models/news_comment.dart';
import '../services/news_service.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PostCard extends StatefulWidget {
  final NewsPost post;
  final NewsService newsService;

  const PostCard({super.key, required this.post, required this.newsService});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool? _isLiked;
  int? _likeCount;

  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    flutterTts.setVolume(1.0);
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_isSpeaking) {
      await flutterTts.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await flutterTts.setVolume(1.0);
      flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      await flutterTts.speak(widget.post.content);
    }
  }

  void _showEditDialog(BuildContext context) {
    final TextEditingController editCtrl = TextEditingController(text: widget.post.content);
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
                widget.newsService.editPost(widget.post.id, editCtrl.text.trim());
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

  void _sharePost() async {
    final authorName = widget.post.isAnonymous
        ? "an Anonymous User"
        : await widget.newsService.getUserName(widget.post.authorId);
    final shareText = "Check out this post by $authorName:\n\n${widget.post.content}";
    Share.share(shareText);
  }

  void _handleLikeToggle(bool serverIsLiked, int serverCount) async {
    final currentLiked = _isLiked ?? serverIsLiked;
    final currentCount = _likeCount ?? serverCount;

    final newLiked = !currentLiked;
    final newCount = currentCount + (newLiked ? 1 : -1);

    setState(() {
      _isLiked = newLiked;
      _likeCount = newCount;
    });

    try {
      await widget.newsService.toggleLike(widget.post.id, currentLiked);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = currentLiked;
          _likeCount = currentCount;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update reaction: $e')),
        );
      }
    }
  }

  void _showCommentsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CommentsBottomSheet(
        post: widget.post,
        newsService: widget.newsService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMine = widget.post.authorId == widget.newsService.currentUserId;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: widget.post.isAnonymous
                ? const Text('Anonymous')
                : FutureBuilder<String>(
              future: widget.newsService.getUserName(widget.post.authorId),
              builder: (context, snapshot) {
                return Text(snapshot.data ?? 'Loading...');
              },
            ),
            subtitle: widget.post.locationName != null
                ? Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(widget.post.locationName!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.volume_up, color: Colors.blue),
                  onPressed: _toggleSpeech,
                  tooltip: 'Listen to post',
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'delete') {
                      await widget.newsService.deletePost(widget.post.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
                    }
                    if (value == 'edit') _showEditDialog(context);
                    if (value == 'report') {
                      await widget.newsService.reportPost(widget.post.id);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent to admin for verify')));
                    }
                  },
                  itemBuilder: (context) => [
                    if (isMine && widget.post.status == 'active') const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (isMine && widget.post.status == 'active') const PopupMenuItem(value: 'delete', child: Text('Delete')),
                    if (!isMine && widget.post.status == 'active') const PopupMenuItem(value: 'report', child: Text('Report')),
                  ],
                ),
              ],
            ),
          ),
          if (widget.post.status == 'user_deleted')
            const Padding(padding: EdgeInsets.all(16.0), child: Text('This post was deleted by the author', style: TextStyle(color: Colors.grey)))
          else if (widget.post.status == 'admin_removed')
            const Padding(padding: EdgeInsets.all(16.0), child: Text('This post was removed by an admin', style: TextStyle(color: Colors.red)))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.post.imageUrl != null) Image.network(widget.post.imageUrl!),
                Padding(padding: const EdgeInsets.all(12.0), child: Text(widget.post.content)),
                if (widget.post.isEdited) const Padding(padding: EdgeInsets.only(left: 12.0, bottom: 8.0), child: Text('(Edited)', style: TextStyle(color: Colors.grey, fontSize: 12))),

                const Divider(),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: widget.newsService.getLikesStream(widget.post.id),
                  builder: (context, snapshot) {
                    final likes = snapshot.data ?? [];
                    final serverIsLiked = likes.any((like) => like['user_id'] == widget.newsService.currentUserId);
                    final serverCount = likes.length;

                    if (snapshot.hasData && _isLiked == serverIsLiked) {
                      _isLiked = null;
                      _likeCount = null;
                    }

                    final displayIsLiked = _isLiked ?? serverIsLiked;
                    final displayCount = _likeCount ?? serverCount;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () => _handleLikeToggle(serverIsLiked, serverCount),
                          icon: Icon(
                            displayIsLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            color: displayIsLiked ? Theme.of(context).colorScheme.primary : null,
                          ),
                          label: Text('$displayCount'),
                        ),
                        StreamBuilder<List<NewsComment>>(
                          stream: widget.newsService.getCommentsStream(widget.post.id),
                          builder: (context, commentSnap) {
                            final count = commentSnap.data?.length ?? 0;
                            return TextButton.icon(
                              onPressed: () => _showCommentsSheet(context),
                              icon: const Icon(Icons.comment_outlined),
                              label: Text(count > 0 ? 'Comment ($count)' : 'Comment'),
                            );
                          },
                        ),
                        TextButton.icon(
                          onPressed: _sharePost,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Share'),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CommentsBottomSheet extends StatefulWidget {
  final NewsPost post;
  final NewsService newsService;

  const _CommentsBottomSheet({required this.post, required this.newsService});

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  final List<NewsComment> _optimisticComments = [];

  void _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final tempComment = NewsComment(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.post.id,
      authorId: widget.newsService.currentUserId ?? 'me',
      content: text,
      status: 'active',
    );

    setState(() {
      _optimisticComments.add(tempComment);
    });
    _commentCtrl.clear();

    try {
      await widget.newsService.addComment(widget.post.id, text);
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticComments.removeWhere((c) => c.id == tempComment.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: StreamBuilder<List<NewsComment>>(
                stream: widget.newsService.getCommentsStream(widget.post.id),
                builder: (context, snapshot) {
                  final serverComments = snapshot.data ?? [];

                  final combinedComments = [...serverComments];
                  for (var temp in _optimisticComments) {
                    if (!combinedComments.any((c) => c.content == temp.content && c.authorId == temp.authorId)) {
                      combinedComments.add(temp);
                    }
                  }

                  if (snapshot.connectionState == ConnectionState.waiting && combinedComments.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (combinedComments.isEmpty) {
                    return const Center(child: Text('No comments yet.'));
                  }

                  return ListView.builder(
                    itemCount: combinedComments.length,
                    itemBuilder: (context, index) {
                      final comment = combinedComments[index];
                      final isMyComment = comment.authorId == widget.newsService.currentUserId;
                      final isPending = comment.id.startsWith('temp_');

                      if (comment.status == 'admin_removed') {
                        return const ListTile(title: Text('Comment removed by admin', style: TextStyle(color: Colors.red)));
                      }

                      return ListTile(
                        title: Text(comment.content),
                        subtitle: isPending
                            ? const Text('Sending...')
                            : FutureBuilder<String>(
                          future: widget.newsService.getUserName(comment.authorId),
                          builder: (context, snapshot) {
                            return Text(snapshot.data ?? 'Loading...');
                          },
                        ),
                        trailing: isPending
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : PopupMenuButton<String>(
                          onSelected: (val) async {
                            if (val == 'report') {
                              await widget.newsService.reportComment(comment.id);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comment reported')));
                            } else if (val == 'delete') {
                              await widget.newsService.deleteComment(comment.id);
                            }
                          },
                          itemBuilder: (context) => [
                            if (!isMyComment) const PopupMenuItem(value: 'report', child: Text('Report')),
                            if (isMyComment) const PopupMenuItem(value: 'delete', child: Text('Delete')),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentCtrl,
                      decoration: const InputDecoration(hintText: 'Add a comment...', border: OutlineInputBorder()),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: Theme.of(context).colorScheme.primary,
                    onPressed: _submitComment,
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}