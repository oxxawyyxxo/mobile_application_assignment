class NewsPost{
  final String id;
  final String authorId;
  final String content;
  final String? imageUrl;
  final bool isAnonymous;
  final bool isEdited;
  final String status;

  NewsPost({
    required this.id,
    required this.authorId,
    required this.content,
    this.imageUrl,
    required this.isAnonymous,
    required this.isEdited,
    required this.status
  });

  factory NewsPost.fromMap(Map<String, dynamic> map){
    return NewsPost(
        id: map['id'],
        authorId: map['author_id'],
        content: map['content'],
        imageUrl: map['image_url'],
        isAnonymous: map['is_anonymous'] ?? false,
        isEdited: map['is_edited'] ?? false,
        status: map['status'] ?? 'active'
    );
  }
}