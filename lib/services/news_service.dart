import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/news_post.dart';
import '../models/official_news.dart';
import 'news_local_db.dart';
import 'dart:convert';

class NewsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final NewsLocalDb _localDb = NewsLocalDb();

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<bool> checkIfBanned() async {
    if (currentUserId == null) return false;
    final res = await _supabase.from('banned_users').select().eq('user_id', currentUserId!).maybeSingle();
    return res != null;
  }

  Stream<List<NewsPost>> getPostsStream() {
    return _supabase.from('news_posts').stream(primaryKey: ['id']).order('created_at').map((data) {
      final posts = data.map((e) => NewsPost.fromMap(e)).toList();
      _localDb.cachePosts(posts);
      return posts;
    });
  }

  Future<void> submitPost({required String content, XFile? imageFile, required bool isAnonymous}) async {
    if (currentUserId == null) return;

    try {
      String? imageUrl;

      if (imageFile != null) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final bytes = await imageFile.readAsBytes();

        await _supabase.storage.from('news_images').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        imageUrl = _supabase.storage.from('news_images').getPublicUrl(fileName);
      }

      await _supabase.from('news_posts').insert({
        'author_id': currentUserId,
        'content': content,
        'image_url': imageUrl,
        'is_anonymous': isAnonymous,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('post_draft');

    } catch (e) {
      print('=== SUBMIT POST ERROR ===');
      print(e.toString());
      throw Exception('Failed to post: $e');
    }
  }

  Future<List<OfficialNews>> getOfficialNews() async {
    try {
      final url = Uri.parse('https://api.spaceflightnewsapi.net/v4/articles/?limit=15');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final articles = data['results'] as List;

        final newsList = articles.map((item) => OfficialNews(
          title: item['title']?.toString() ?? 'No Title',
          description: item['summary']?.toString() ?? 'No description.',
          pubDate: item['published_at']?.toString() ?? '',
          link: item['url']?.toString() ?? '',
        )).toList();

        await _localDb.cacheOfficialNews(newsList);
        return newsList;
      } else {
        print('API returned status code: ${response.statusCode}');
      }
    } catch (e) {
      print('=== OFFICIAL NEWS API ERROR ===');
      print(e.toString());
    }
    return await _localDb.getCachedOfficialNews();
  }

  Future<void> editPost(String postId, String newContent) async {
    await _supabase.from('news_posts').update({
      'content': newContent,
      'is_edited': true
    }).eq('id', postId);
  }

  Future<void> deletePost(String postId) async {
    await _supabase.from('news_posts').update({'status': 'user_deleted'}).eq('id', postId);
  }

  Future<void> reportPost(String postId) async {
    if (currentUserId == null) return;
    await _supabase.from('news_reports').insert({
      'post_id': postId,
      'reporter_id': currentUserId,
      'reason': 'Inappropriate content',
    });
  }

  Future<void> saveDraft(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('post_draft', text);
  }

  Future<String> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('post_draft') ?? '';
  }

  Future<File?> pickAndCompressImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final targetPath = '${picked.path}_compressed.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path, targetPath, quality: 70,
    );
    return compressed != null ? File(compressed.path) : File(picked.path);
  }
}