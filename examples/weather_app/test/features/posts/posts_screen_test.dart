import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/network/api_exception.dart';
import 'package:weather_app/core/storage/key_value_store.dart';
import 'package:weather_app/features/posts/data/posts_repository.dart';
import 'package:weather_app/features/posts/domain/post.dart';
import 'package:weather_app/features/posts/presentation/posts_screen.dart';

import '../../helpers/helpers.dart';

class _SwitchablePostsRepository implements PostsRepository {
  _SwitchablePostsRepository({this.total = postsPageSize * 2});

  bool fail = false;

  /// How many posts exist in total.
  final int total;

  @override
  Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = postsPageSize,
  }) async {
    if (fail) throw const NetworkException('down');
    final start = (page - 1) * limit;
    return [
      for (var id = start + 1; id <= total && id <= start + limit; id++)
        Post(id: id, userId: 1, title: 'Post $id', body: 'body $id'),
    ];
  }

  @override
  Future<Post> fetchPost(int id) async =>
      Post(id: id, userId: 1, title: 'Post $id', body: 'body $id');
}

void main() {
  Future<void> pumpPosts(
    WidgetTester tester,
    _SwitchablePostsRepository repository,
  ) => tester.pumpApp(
    const PostsScreen(),
    overrides: [
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      postsRepositoryProvider.overrideWithValue(repository),
    ],
  );

  group('PostsScreen', () {
    testWidgets('renders the fetched posts', (tester) async {
      await pumpPosts(tester, _SwitchablePostsRepository());
      await tester.pumpAndSettle();

      expect(find.text('Post 1'), findsOneWidget);
    });

    testWidgets('shows the error view and recovers via Retry', (tester) async {
      // Regression: the error/retry path had no widget coverage, which
      // hid both the hardcoded error message and the retry wiring.
      final repository = _SwitchablePostsRepository()..fail = true;
      await pumpPosts(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Failed to load posts.'), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Post 1'), findsOneWidget);
    });

    testWidgets('scrolling to the bottom appends the next page', (
      tester,
    ) async {
      await pumpPosts(tester, _SwitchablePostsRepository());
      await tester.pumpAndSettle();

      // Page 2 starts here and cannot exist yet.
      expect(find.text('Post ${postsPageSize + 1}'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Post ${postsPageSize * 2}'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Post ${postsPageSize * 2}'), findsOneWidget);
    });

    testWidgets('announces the end of the list once every page is in', (
      tester,
    ) async {
      // A single short page: the first fetch already proves there is no
      // more, so the footer must say so without any scrolling.
      await pumpPosts(tester, _SwitchablePostsRepository(total: 3));
      await tester.pumpAndSettle();

      expect(find.text("You've reached the end."), findsOneWidget);
    });

    testWidgets('a failed next page keeps the posts already on screen', (
      tester,
    ) async {
      final repository = _SwitchablePostsRepository();
      await pumpPosts(tester, repository);
      await tester.pumpAndSettle();

      repository.fail = true;
      await tester.scrollUntilVisible(
        find.text('Post $postsPageSize'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't load more posts."), findsOneWidget);
      expect(
        find.text('Post $postsPageSize'),
        findsOneWidget,
        reason: 'the loaded page must survive a failed next page',
      );
      expect(
        find.text('Failed to load posts.'),
        findsNothing,
        reason: 'a next-page failure must not take over the screen',
      );
    });
  });
}
