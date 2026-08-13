import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/network/api_exception.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/posts/data/posts_repository.dart';
import 'package:todo_app/features/posts/domain/post.dart';
import 'package:todo_app/features/posts/presentation/post_detail_screen.dart';

import '../../helpers/helpers.dart';

/// Fetches one post, or fails with whatever the test asks for.
///
/// `fetchPosts` is never reached from the detail screen; it throws rather
/// than returning an empty list so a test that accidentally exercises the
/// list path fails loudly instead of quietly passing.
class _SinglePostRepository implements PostsRepository {
  _SinglePostRepository({this.failure});

  /// Thrown by [fetchPost] instead of returning, when set. Mutable so a
  /// test can end the outage and retry.
  Exception? failure;

  @override
  Future<List<Post>> fetchPosts({int page = 1, int limit = postsPageSize}) =>
      throw UnimplementedError('the detail screen does not list posts');

  @override
  Future<Post> fetchPost(int id) async {
    final error = failure;
    if (error != null) throw error;
    return Post(id: id, userId: 1, title: 'Post $id', body: 'body of $id');
  }
}

void main() {
  Future<void> pumpWith(
    WidgetTester tester,
    _SinglePostRepository repository,
  ) => tester.pumpApp(
    const PostDetailScreen(postId: 42),
    overrides: [
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      postsRepositoryProvider.overrideWithValue(repository),
    ],
  );

  Future<void> pumpDetail(WidgetTester tester, {Exception? failure}) =>
      pumpWith(tester, _SinglePostRepository(failure: failure));

  group('PostDetailScreen', () {
    testWidgets('renders the post it fetched', (tester) async {
      await pumpDetail(tester);
      await tester.pumpAndSettle();

      expect(find.text('Post 42'), findsOneWidget);
      expect(find.text('body of 42'), findsOneWidget);
    });

    testWidgets('a 404 says the post was not found', (tester) async {
      // The only per-error message customisation in the app, and it was
      // once unreachable: the offline cache swallowed server errors, so
      // every failure arrived as the generic one. The repository-layer fix
      // for that has a test; this is the branch it was protecting.
      await pumpDetail(
        tester,
        failure: const ServerException('not found', statusCode: 404),
      );
      await tester.pumpAndSettle();

      expect(find.text('Post not found.'), findsOneWidget);
      expect(find.text('Failed to load posts.'), findsNothing);
    });

    testWidgets('any other server failure keeps the generic message', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        failure: const ServerException('boom', statusCode: 500),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load posts.'), findsOneWidget);
      expect(find.text('Post not found.'), findsNothing);
    });

    testWidgets('a transport failure keeps the generic message', (
      tester,
    ) async {
      // NetworkException carries no status code at all — the 404 test
      // above would still pass if the check were `error is ServerException`
      // alone, so the non-ServerException side needs its own case.
      await pumpDetail(tester, failure: const NetworkException('offline'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to load posts.'), findsOneWidget);
      expect(find.text('Post not found.'), findsNothing);
    });

    testWidgets('Retry refetches once the failure is over', (tester) async {
      // A detail screen that shows an error with no way out is the same
      // dead end the unmatched-route regression was about, so the button
      // has to actually re-run the provider rather than merely exist.
      final repository = _SinglePostRepository(
        failure: const ServerException('gone', statusCode: 500),
      );
      await pumpWith(tester, repository);
      await tester.pumpAndSettle();
      expect(find.text('Failed to load posts.'), findsOneWidget);

      repository.failure = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Post 42'), findsOneWidget);
      expect(find.text('Failed to load posts.'), findsNothing);
    });

    testWidgets('the body is capped and top-anchored on a wide window', (
      tester,
    ) async {
      // Design spec 005. The scroll view is what carries the cap; the
      // column inside it can never be 840 because it sits inside the 24pt
      // padding, which is the criterion the issue got wrong.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);

      await pumpDetail(tester);
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(SingleChildScrollView)).width, 840);
      // Centred horizontally, and still starting at the top of the body.
      final title = tester.getRect(find.text('Post 42'));
      expect(title.left, 304);
      expect(title.top, 80);
    });

    testWidgets('nothing moves at phone width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await pumpDetail(tester);
      await tester.pumpAndSettle();

      final title = tester.getRect(find.text('Post 42'));
      expect(title.left, 24);
      expect(title.top, 80);
    });
  });
}
