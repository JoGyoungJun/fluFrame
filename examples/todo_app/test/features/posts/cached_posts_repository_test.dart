import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/network/api_exception.dart';
import 'package:todo_app/features/posts/data/cached_posts_repository.dart';
import 'package:todo_app/features/posts/data/posts_repository.dart';
import 'package:todo_app/features/posts/domain/post.dart';

import '../../helpers/helpers.dart';

class _SwitchableInner implements PostsRepository {
  bool fail = false;

  /// Raised instead of a [NetworkException] when set.
  ApiException? failWith;

  static const posts = [
    Post(id: 1, userId: 1, title: 'cached title', body: 'body'),
  ];

  static const laterPage = [
    Post(id: 2, userId: 1, title: 'page two title', body: 'body'),
  ];

  @override
  Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = postsPageSize,
  }) async {
    if (failWith != null) throw failWith!;
    if (fail) throw const NetworkException('down');
    return page == 1 ? posts : laterPage;
  }

  @override
  Future<Post> fetchPost(int id) async =>
      (await fetchPosts()).firstWhere((post) => post.id == id);
}

void main() {
  group('CachedPostsRepository', () {
    late _SwitchableInner inner;
    late InMemoryKeyValueStore store;
    late CachedPostsRepository repository;

    setUp(() {
      inner = _SwitchableInner();
      store = InMemoryKeyValueStore();
      repository = CachedPostsRepository(inner, store);
    });

    test('a successful fetch caches the response', () async {
      await repository.fetchPosts();

      expect(await store.getString('cache.posts'), contains('cached title'));
    });

    test('serves the cache when the network fails', () async {
      await repository.fetchPosts();
      inner.fail = true;

      expect(await repository.fetchPosts(), _SwitchableInner.posts);
    });

    test('rethrows when the network fails with no cache', () async {
      inner.fail = true;

      expect(repository.fetchPosts, throwsA(isA<NetworkException>()));
    });

    test('a server error is never masked by the cache', () async {
      // Regression: the fallback caught every ApiException, so a 404 or a
      // 500 was answered with a stale copy. PostDetailScreen's 404 branch
      // could therefore never run, and a broken endpoint looked healthy.
      await repository.fetchPosts();
      inner.failWith = const ServerException('gone', statusCode: 404);

      await expectLater(
        repository.fetchPosts,
        throwsA(isA<ServerException>()),
      );
      await expectLater(
        () => repository.fetchPost(1),
        throwsA(
          isA<ServerException>().having(
            (error) => error.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('fetchPost falls back to the cached list', () async {
      await repository.fetchPosts();
      inner.fail = true;

      expect(await repository.fetchPost(1), _SwitchableInner.posts.first);
    });

    test('fetchPost rethrows for an id missing from the cache', () async {
      await repository.fetchPosts();
      inner.fail = true;

      expect(() => repository.fetchPost(99), throwsA(isA<NetworkException>()));
    });

    test('only the first page is cached', () async {
      await repository.fetchPosts(page: 2);

      expect(await store.getString('cache.posts'), isNull);
    });

    test('a later page does not fall back to the cache', () async {
      // The cache holds page 1; answering a page-2 request with it would
      // hand the controller a duplicate page and stall the list forever.
      await repository.fetchPosts();
      inner.fail = true;

      expect(
        () => repository.fetchPosts(page: 2),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}
