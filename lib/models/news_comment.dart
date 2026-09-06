class NewsComment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final String status;

  NewsComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.status,
  });

  factory NewsComment.fromMap(Map<String, dynamic> map) {
    return NewsComment(
      id: map['id'],
      postId: map['post_id'],
      authorId: map['author_id'],
      content: map['content'],
      status: map['status'] ?? 'active',
    );
  }
}