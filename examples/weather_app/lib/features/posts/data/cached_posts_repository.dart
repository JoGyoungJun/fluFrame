import 'dart:convert';

import 'package:weather_app/core/network/api_exception.dart';
import 'package:weather_app/core/storage/key_value_store.dart';
import 'package:weather_app/features/posts/data/posts_repository.dart';
import 'package:weather_app/features/posts/domain/post.dart';

/// Offline fallback decorator over [PostsRepository]: every successful
/// fetch is cached in the [KeyValueStore]; when the network fails with an
/// [ApiException], the last cached response is served instead. Without a
/// cache the failure propagates untouched.
class CachedPostsRepository implements PostsRepository {
  /// Wraps [inner], persisting responses in [store].
  CachedPostsRepository(PostsRepository inner, KeyValueStore store)
    : _inner = inner,
      _store = store;

  final PostsRepository _inner;
  final KeyValueStore _store;

  static const String _cacheKey = 'cache.posts';

  @override
  Future<List<Post>> fetchPosts() async {
    try {
      final posts = await _inner.fetchPosts();
      await _store.setString(
        _cacheKey,
        jsonEncode([for (final post in posts) post.toJson()]),
      );
      return posts;
    } on ApiException {
      final cached = await _readCache();
      if (cached == null) rethrow;
      return cached;
    }
  }

  @override
  Future<Post> fetchPost(int id) async {
    try {
      return await _inner.fetchPost(id);
    } on ApiException {
      final cached = await _readCache();
      if (cached != null) {
        for (final post in cached) {
          if (post.id == id) return post;
        }
      }
      rethrow;
    }
  }

  Future<List<Post>?> _readCache() async {
    final raw = await _store.getString(_cacheKey);
    if (raw == null) return null;
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final json in list) Post.fromJson(json as Map<String, Object?>),
    ];
  }
}
