import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/network/api_exception.dart';
import 'package:weather_app/features/posts/data/posts_repository.dart';
import 'package:weather_app/features/posts/domain/post.dart';
import 'package:weather_app/features/posts/presentation/posts_controller.dart';

import '../../helpers/helpers.dart';

class _FakePostsRepository implements PostsRepository {
  _FakePostsRepository(this._fetch);

  final Future<List<Post>> Function() _fetch;

  @override
  Future<List<Post>> fetchPosts() => _fetch();

  @override
  Future<Post> fetchPost(int id) async =>
      (await _fetch()).firstWhere((post) => post.id == id);
}

void main() {
  const posts = [Post(id: 1, userId: 1, title: 'title', body: 'body')];

  group('PostsController', () {
    test('build exposes the fetched posts', () async {
      final container = createContainer(
        overrides: [
          postsRepositoryProvider.overrideWithValue(
            _FakePostsRepository(() async => posts),
          ),
        ],
      );

      await expectLater(
        container.read(postsControllerProvider.future),
        completion(posts),
      );
    });

    test('failures surface as AsyncError', () async {
      final container = createContainer(
        overrides: [
          postsRepositoryProvider.overrideWithValue(
            _FakePostsRepository(
              () async => throw const NetworkException('down'),
            ),
          ),
        ],
      );

      await expectLater(
        container.read(postsControllerProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(postsControllerProvider).hasError, isTrue);
    });
  });

  group('PostsController.refresh', () {
    test('does not throw when the fetch fails', () async {
      // Regression: refresh() used to rethrow, and RefreshIndicator
      // discards onRefresh errors — every failed pull-to-refresh became
      // an unhandled async exception.
      var fail = false;
      final container = createContainer(
        overrides: [
          postsRepositoryProvider.overrideWithValue(
            _FakePostsRepository(
              () async => fail ? throw const NetworkException('down') : posts,
            ),
          ),
        ],
      );
      await container.read(postsControllerProvider.future);

      fail = true;
      await container.read(postsControllerProvider.notifier).refresh();

      expect(container.read(postsControllerProvider).hasError, isTrue);
    });
  });

  group('postProvider', () {
    test('fetches the post matching the id', () async {
      final container = createContainer(
        overrides: [
          postsRepositoryProvider.overrideWithValue(
            _FakePostsRepository(() async => posts),
          ),
        ],
      );

      await expectLater(
        container.read(postProvider(1).future),
        completion(posts.first),
      );
    });
  });
}
