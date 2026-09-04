import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/news_post.dart';
import '../models/official_news.dart';

class NewsLocalDb {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'news_cache_v2.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_posts (
            id TEXT PRIMARY KEY,
            author_id TEXT,
            content TEXT,
            image_url TEXT,
            is_anonymous INTEGER,
            is_edited INTEGER,
            status TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_official_news (
            link TEXT PRIMARY KEY,
            title TEXT,
            description TEXT,
            pubDate TEXT
          )
        ''');
      },
    );
  }

  Future<void> cachePosts(List<NewsPost> posts) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_posts');
    for (var post in posts) {
      batch.insert('cached_posts', {
        'id': post.id,
        'author_id': post.authorId,
        'content': post.content,
        'image_url': post.imageUrl,
        'is_anonymous': post.isAnonymous ? 1 : 0,
        'is_edited': post.isEdited ? 1 : 0,
        'status': post.status,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> cacheOfficialNews(List<OfficialNews> newsList) async {
    final db = await database;
    final batch = db.batch();
    batch.delete('cached_official_news');
    for (var news in newsList) {
      batch.insert('cached_official_news', {
        'link': news.link,
        'title': news.title,
        'description': news.description,
        'pubDate': news.pubDate,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<OfficialNews>> getCachedOfficialNews() async {
    final db = await database;
    final maps = await db.query('cached_official_news');
    return maps.map((map) => OfficialNews.fromMap(map)).toList();
  }
}