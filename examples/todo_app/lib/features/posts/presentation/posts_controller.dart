import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:todo_app/features/posts/data/posts_repository.dart';
import 'package:todo_app/features/posts/domain/post.dart';

/// Loads the post list and exposes it as an [AsyncValue].
class PostsController extends AsyncNotifier<List<Post>> {
  @override
  Future<List<Post>> build() => ref.watch(postsRepositoryProvider).fetchPosts();

  /// Discards the current state and re-runs [build].
  ///
  /// Failures are not rethrown: they are already surfaced to the UI as
  /// [AsyncError] state, and callers like `RefreshIndicator.onRefresh`
  /// discard the returned future's error (which would otherwise become an
  /// unhandled async exception).
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Surfaced via AsyncError state.
    }
  }
}

/// Provider for the [PostsController].
final postsControllerProvider =
    AsyncNotifierProvider<PostsController, List<Post>>(PostsController.new);

/// Fetches a single post by id for the detail screen.
final FutureProviderFamily<Post, int> postProvider = FutureProvider.autoDispose
    .family<Post, int>(
      (ref, id) => ref.watch(postsRepositoryProvider).fetchPost(id),
    );
