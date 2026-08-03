import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/features/posts/data/cached_posts_repository.dart';
import 'package:fluframe_app/features/posts/data/posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

class _SwitchableInner implements PostsRepository {
  bool fail = false;

  static const posts = [
    Post(id: 1, userId: 1, title: 'cached title', body: 'body'),
  ];

  @override
  Future<List<Post>> fetchPosts() async =>
      fail ? throw const NetworkException('down') : posts;

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
  });
}
