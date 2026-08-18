import 'dart:convert';

import 'package:todo_app/core/logging/app_logger.dart';
import 'package:todo_app/core/network/api_exception.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/posts/data/posts_repository.dart';
import 'package:todo_app/features/posts/domain/post.dart';

/// Offline fallback decorator over [PostsRepository]: every successful
/// fetch is cached in the [KeyValueStore] — best effort, never at the
/// cost of the fetch it decorates; when the device cannot reach the
/// server ([NetworkException]), the last cached response is served
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

  static const AppLogger _logger = AppLogger('todo_app.posts');

  /// Schema version of the cached blob.
  ///
  /// The cache is only ever written by a *successful* fetch, so a blob can
  /// outlive the release that wrote it for as long as a device stays
  /// offline. Bump this whenever [Post]'s JSON shape changes: a blob whose
  /// version this build does not recognise is discarded instead of parsed,
  /// which is what stops a shape change from breaking the offline path of
  /// every already-installed app — the one situation the cache exists for.
  static const int _cacheSchema = 1;

  @override
  Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = postsPageSize,
  }) async {
    try {
      final posts = await _inner.fetchPosts(page: page, limit: limit);
      if (page == 1) await _writeCache(posts);
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

  /// Caches [posts]; a store that refuses the write is not an error here.
  ///
  /// The write used to share the `try` that wraps the fetch, whose only
  /// handler is for [NetworkException] — so a store failure escaped
  /// [fetchPosts] *after* the fetch had succeeded, and `PostsController`
  /// turned posts it was already holding into a full-screen error. None
  /// of the ways this fails is a network failure: a `PlatformException`
  /// from the preferences plugin, a full disk, a quota error from web
  /// `localStorage`. Caching is additive — a write that did not happen
  /// is a future cache miss, not a present failure.
  Future<void> _writeCache(List<Post> posts) async {
    try {
      await _store.setString(
        _cacheKey,
        jsonEncode({
          'version': _cacheSchema,
          'posts': [for (final post in posts) post.toJson()],
        }),
      );
    } on Object catch (error) {
      // `on Object`, not `on Exception`: the web quota failure arrives as
      // an Error, and failing the fetch is the one outcome ruled out.
      _logger.warning('Caching posts failed: $error');
    }
  }

  /// The cached posts, or `null` when there is no cache this build can use.
  ///
  /// Every failure is the same answer — a store that will not answer,
  /// unreadable JSON, a version this build does not know, a payload of the
  /// wrong shape: there is no usable cache. This runs inside
  /// `on NetworkException`, so anything thrown here would replace the real
  /// reason the caller failed with a storage or parse error. Worse,
  /// `Post.fromJson` on the wrong shape raises a `TypeError`, which is an
  /// `Error` rather than an `Exception` — `PostsController` does not catch
  /// it at all, so it would reach the user as a crash.
  ///
  /// An unusable blob is deleted rather than left in place. It cannot
  /// become readable again, and the device may stay offline for a long
  /// time; dropping it means the next read is simply a cache miss.
  Future<List<Post>?> _readCache() async {
    try {
      final raw = await _store.getString(_cacheKey);
      if (raw == null) return null;
      try {
        final posts = _decodeCache(raw);
        if (posts != null) return posts;
      } on Object {
        // Falls through to the discard below: whatever it was, it is not
        // a cache, and the caller's NetworkException is the useful error.
      }
      await _store.remove(_cacheKey);
    } on Object {
      // The read and the discard sat outside the guard above, so a store
      // that threw here replaced the caller's NetworkException with a
      // storage error and the offline path was never taken. Same answer
      // as every other failure: no usable cache.
    }
    return null;
  }

  /// Parses [raw], or returns `null` when it is not a blob this build wrote.
  List<Post>? _decodeCache(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    if (decoded['version'] != _cacheSchema) return null;
    final posts = decoded['posts'];
    if (posts is! List) return null;
    return [
      for (final json in posts) Post.fromJson(json as Map<String, Object?>),
    ];
  }
}
