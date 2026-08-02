import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/posts/data/posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';
import 'package:fluframe_app/features/posts/presentation/posts_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

class _SwitchablePostsRepository implements PostsRepository {
  bool fail = false;

  static const _posts = [
    Post(id: 1, userId: 1, title: 'First post', body: 'body'),
  ];

  @override
  Future<List<Post>> fetchPosts() async =>
      fail ? throw const NetworkException('down') : _posts;

  @override
  Future<Post> fetchPost(int id) async =>
      (await fetchPosts()).firstWhere((post) => post.id == id);
}

void main() {
  group('PostsScreen', () {
    testWidgets('renders the fetched posts', (tester) async {
      final repository = _SwitchablePostsRepository();
      await tester.pumpApp(
        const PostsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          postsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('First post'), findsOneWidget);
    });

    testWidgets('shows the error view and recovers via Retry', (tester) async {
      // Regression: the error/retry path had no widget coverage, which
      // hid both the hardcoded error message and the retry wiring.
      final repository = _SwitchablePostsRepository()..fail = true;
      await tester.pumpApp(
        const PostsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          postsRepositoryProvider.overrideWithValue(repository),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load posts.'), findsOneWidget);

      repository.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('First post'), findsOneWidget);
    });
  });
}
