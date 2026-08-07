import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:todo_app/features/posts/domain/post.dart';

part 'posts_state.freezed.dart';

/// The paginated post list as the screen sees it.
///
/// The surrounding `AsyncValue` carries the **first** page's loading and
/// error state — the one that owns the whole screen. These fields carry
/// the **next** page's, which must never replace what the user is already
/// reading.
@freezed
abstract class PostsState with _$PostsState {
  /// Creates a [PostsState].
  const factory PostsState({
    /// Every post loaded so far, in order.
    @Default(<Post>[]) List<Post> posts,

    /// Whether another page is expected to exist.
    @Default(true) bool hasMore,

    /// Whether the next page is being fetched right now.
    @Default(false) bool isLoadingMore,

    /// Why the last next-page fetch failed, or `null` if it did not.
    Object? loadMoreError,
  }) = _PostsState;
}
