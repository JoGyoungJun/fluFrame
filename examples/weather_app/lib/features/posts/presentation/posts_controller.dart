import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:weather_app/features/posts/data/posts_repository.dart';
import 'package:weather_app/features/posts/domain/post.dart';
import 'package:weather_app/features/posts/presentation/posts_state.dart';

/// Loads the post list one page at a time and exposes it as an
/// [AsyncValue] of [PostsState].
///
/// See `docs/design/004-paginated-posts.md`.
class PostsController extends AsyncNotifier<PostsState> {
  /// Bumped by every [build], i.e. by every refresh or invalidation.
  ///
  /// `ref.invalidate` reuses this notifier instance and leaves it mounted,
  /// so a [loadMore] that was already awaiting its response can still
  /// write to [state] afterwards — silently appending a stale page onto
  /// the freshly reloaded first one. Comparing the generation it started
  /// with is what stops that; `ref.mounted` does not, because the notifier
  /// never became unmounted.
  int _generation = 0;

  @override
  Future<PostsState> build() async {
    _generation++;
    final posts = await ref.watch(postsRepositoryProvider).fetchPosts();
    return PostsState(posts: posts, hasMore: posts.length >= postsPageSize);
  }

  /// Appends the next page, if there is one and none is already loading.
  ///
  /// Called from the scroll listener, which fires repeatedly while the
  /// user sits near the bottom — the guards below are what make that
  /// harmless, so they belong here rather than in the listener.
  Future<void> loadMore() async {
    if (!state.hasValue) return;
    final current = state.requireValue;
    if (current.isLoadingMore || !current.hasMore) return;

    final generation = _generation;
    // Built explicitly rather than with copyWith: freezed reads a `null`
    // argument as "leave unchanged", so copyWith cannot clear
    // loadMoreError.
    state = AsyncData(
      PostsState(
        posts: current.posts,
        hasMore: current.hasMore,
        isLoadingMore: true,
      ),
    );

    // The page number is derived from what is loaded rather than tracked
    // separately, so the two cannot disagree.
    final page = current.posts.length ~/ postsPageSize + 1;
    try {
      final next = await ref
          .read(postsRepositoryProvider)
          .fetchPosts(page: page);
      if (generation != _generation) return;
      state = AsyncData(
        PostsState(
          posts: [...current.posts, ...next],
          hasMore: next.length >= postsPageSize,
        ),
      );
    } on Exception catch (error) {
      if (generation != _generation) return;
      state = AsyncData(
        PostsState(
          posts: current.posts,
          hasMore: current.hasMore,
          loadMoreError: error,
        ),
      );
    }
  }

  /// Discards the current state and re-runs [build], back to page one.
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
    AsyncNotifierProvider<PostsController, PostsState>(PostsController.new);

/// Fetches a single post by id for the detail screen.
final FutureProviderFamily<Post, int> postProvider = FutureProvider.autoDispose
    .family<Post, int>(
      (ref, id) => ref.watch(postsRepositoryProvider).fetchPost(id),
    );
