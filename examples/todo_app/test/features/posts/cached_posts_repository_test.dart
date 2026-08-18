import 'dart:convert';

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

    group('an unusable cache blob', () {
      // A blob is only ever written by a *successful* fetch, so it can
      // outlive the release that wrote it for as long as the device stays
      // offline. Before the schema guard, every one of these replaced the
      // caller's NetworkException with a parse failure — and the wrong-shape
      // case with a TypeError, which is an Error, not an Exception, so
      // PostsController's `on Exception` never caught it at all.
      const cases = {
        'not JSON at all': 'not json {{{',
        'JSON, but not an object': '[]',
        'no version, the shape written before this guard existed':
            '[{"id":1,"userId":1,"title":"t","body":"b"}]',
        'a version this build does not know': '{"version":99,"posts":[]}',
        'posts is not a list': '{"version":1,"posts":"nope"}',
        'posts holds the wrong shape': '{"version":1,"posts":[{"nope":1}]}',
      };

      for (final MapEntry(key: name, value: blob) in cases.entries) {
        test('$name — the caller still sees the network error', () async {
          await store.setString('cache.posts', blob);
          inner.fail = true;

          await expectLater(
            repository.fetchPosts(),
            throwsA(isA<NetworkException>()),
          );
          await expectLater(
            repository.fetchPost(1),
            throwsA(isA<NetworkException>()),
          );
        });

        test('$name — is discarded rather than re-parsed forever', () async {
          await store.setString('cache.posts', blob);
          inner.fail = true;

          await expectLater(
            repository.fetchPosts(),
            throwsA(isA<NetworkException>()),
          );

          expect(await store.getString('cache.posts'), isNull);
        });
      }

      test('is replaced by the next successful fetch', () async {
        await store.setString('cache.posts', 'not json {{{');

        // Back online: the fetch succeeds and rewrites the blob.
        expect(await repository.fetchPosts(), _SwitchableInner.posts);

        // And the offline path works again from that point on.
        inner.fail = true;
        expect(await repository.fetchPosts(), _SwitchableInner.posts);
      });
    });

    test('the cached blob carries its schema version', () async {
      // The guard is only useful if the writer stamps what the reader
      // checks; a blob without this is indistinguishable from a foreign one.
      await repository.fetchPosts();

      final raw = await store.getString('cache.posts');
      expect(jsonDecode(raw!), containsPair('version', 1));
    });

    group('a store that refuses', () {
      // The store is a plugin, not a pure function: shared_preferences
      // raises a PlatformException when the platform side fails, and web
      // localStorage a quota error once it is full. Neither is a
      // NetworkException, and this decorator handles nothing else — so
      // every one of them used to escape as the fetch's own failure.
      late FailingKeyValueStore failing;

      setUp(() {
        failing = FailingKeyValueStore();
        repository = CachedPostsRepository(inner, failing);
      });

      test('a failed write still returns the posts it fetched', () async {
        // Regression: the write shared the fetch's try block, so a store
        // that would not take it turned a fetch that had already
        // succeeded into an AsyncError — a full-screen error rendered
        // over posts sitting in memory one line above. Caching is
        // additive; a write that did not happen is a later cache miss.
        failing.failWrites = true;

        expect(await repository.fetchPosts(), _SwitchableInner.posts);
      });

      test('a failed read leaves the network error intact', () async {
        // Regression: the read sat outside _readCache's guard, so being
        // offline with an unreadable store replaced the caller's
        // NetworkException with a storage one — and the offline branch,
        // which only NetworkException reaches, was never taken.
        failing.failReads = true;
        inner.fail = true;

        await expectLater(
          repository.fetchPosts(),
          throwsA(isA<NetworkException>()),
        );
        await expectLater(
          repository.fetchPost(1),
          throwsA(isA<NetworkException>()),
        );
      });

      test('a failed discard leaves the network error intact', () async {
        // Same defect, other end: the discard of an unusable blob sat
        // outside the guard too, so a store that refused the delete
        // reported itself instead of the network.
        await failing.setString('cache.posts', 'not json {{{');
        failing.failRemovals = true;
        inner.fail = true;

        await expectLater(
          repository.fetchPosts(),
          throwsA(isA<NetworkException>()),
        );
      });
    });
  });
}
