import 'dart:convert';

import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/posts/data/posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';

/// Offline fallback decorator over [PostsRepository]: every successful
/// fetch is cached in the [KeyValueStore]; when the device cannot reach
/// the server ([NetworkException]), the last cached response is served
/// instead. Without a cache the failure propagates untouched.
///
/// Only [NetworkException] falls back. A [ServerException] means the
/// server answered — a 404 for a deleted post, a 500 for a broken
/// endpoint — and serving a stale copy would hide it: the 404 branch in
/// `PostDetailScreen` was unreachable for exactly that reason.
///
/// Only the **first** page is cached, so the offline fallback — including
/// the one [fetchPost] uses — covers the first [postsPageSize] posts
/// rather than every post the user ever scrolled past. Accumulating pages
/// in the cache is deliberately out of scope
/// (`docs/design/004-paginated-posts.md`): the offline story here is "the
/// screen still opens", not "the whole feed is available".
class CachedPostsRepository implements PostsRepository {
  /// Wraps [inner], persisting responses in [store].
  CachedPostsRepository(PostsRepository inner, KeyValueStore store)
    : _inner = inner,
      _store = store;

  final PostsRepository _inner;
  final KeyValueStore _store;

  static const String _cacheKey = 'cache.posts';

  @override
  Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = postsPageSize,
  }) async {
    try {
      final posts = await _inner.fetchPosts(page: page, limit: limit);
      if (page == 1) {
        await _store.setString(
          _cacheKey,
          jsonEncode([for (final post in posts) post.toJson()]),
        );
      }
      return posts;
    } on NetworkException {
      // A later page has nothing sensible to fall back to, and the list
      // screen already keeps what it is showing and offers a retry.
      if (page != 1) rethrow;
      final cached = await _readCache();
      if (cached == null) rethrow;
      return cached;
    }
  }

  @override
  Future<Post> fetchPost(int id) async {
    try {
      return await _inner.fetchPost(id);
    } on NetworkException {
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
