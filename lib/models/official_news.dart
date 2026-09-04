class OfficialNews {
  final String title;
  final String description;
  final String pubDate;
  final String link;

  OfficialNews({
    required this.title,
    required this.description,
    required this.pubDate,
    required this.link,
  });

  factory OfficialNews.fromJson(Map<String, dynamic> json) {
    return OfficialNews(
      title: json['title']?.toString() ?? 'No Title',
      description: json['description']?.toString() ?? 'No description available.',
      pubDate: json['publishedAt']?.toString() ?? 'Unknown Date',
      link: json['url']?.toString() ?? '',
    );
  }

  factory OfficialNews.fromMap(Map<String, dynamic> map) {
    return OfficialNews(
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      pubDate: map['pubDate']?.toString() ?? '',
      link: map['link']?.toString() ?? '',
    );
  }
}