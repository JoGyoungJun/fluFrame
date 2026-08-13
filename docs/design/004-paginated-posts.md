# 004 — Paginated posts (infinite scroll reference pattern)

**Status**: APPROVED · **Issue**: [#101][issue] · **Size**: Feature

## Problem

`features/posts` fetches `/posts` once and renders whatever comes back.
Every real list-backed app needs pagination instead, and the version
people write on their first try is subtly wrong in four specific ways:

1. It replaces the list on every page instead of appending, or appends
   while a refresh is rebuilding it.
2. It fires the same next-page request several times, because the scroll
   listener runs on every frame near the bottom.
3. It never stops, because "no more pages" is not represented anywhere.
4. It throws away everything the user is reading when page 4 fails.

A starter that ships the naive version teaches the naive version. This
spec makes `posts` the reference implementation instead.

### The race is real, not theoretical

Riverpod 3 was measured rather than assumed (probe run 2026-08-08, Riverpod
3.4.2). `ref.invalidate` on an `AsyncNotifierProvider`:

- **reuses the same notifier instance** (the constructor runs once);
- re-runs `build()` on it;
- leaves `ref.mounted` `true`, and a `state = ...` write from an
  operation started *before* the invalidation **succeeds silently**.

So a `loadMore()` still in flight when the user pulls to refresh will
overwrite the fresh first page with `[stale page 1..n, page n+1]`, and
nothing in the framework stops it. `ref.mounted` is not a guard here. A
generation counter is required, and criterion 5 below exists to pin this
down.

## Goals

- Cursor-free offset pagination in `posts`, correct on all four points
  above, with the correctness expressed as tests rather than prose.
- No new dependencies.

## Non-goals

- Caching paginated pages in the offline fallback store (see
  "Consequence" below — this narrows existing behaviour, deliberately).
- Pagination anywhere else, including the examples' own features.
- Switching the demo API away from JSONPlaceholder.
- Prefetching, page-size tuning per connection, or scroll restoration.

## Design

### Data

JSONPlaceholder is json-server-backed and supports `_page` / `_limit`
(verified 2026-08-08: `?_page=2&_limit=3` returns ids 4-6; a page past the
end returns `[]`; `x-total-count: 100` is exposed via CORS). The end is
detected from the page's own length, so no header parsing and no total
count is needed:

```dart
/// How many posts one page holds.
const int postsPageSize = 20;

// PostsRepository
Future<List<Post>> fetchPosts({int page = 1, int limit = postsPageSize});
// GET /posts?_page=$page&_limit=$limit
```

`hasMore` is `returnedPage.length >= limit`. A short page — including the
empty one past the end — means this was the last.

### Consequence for the offline cache

`CachedPostsRepository` caches under one key, `cache.posts`. It keeps
doing exactly that, but the cached value is now **page 1 only**, and only
page 1 falls back:

- `page == 1` and `NetworkException` → serve the cache if present.
- `page > 1` and `NetworkException` → rethrow. There is nothing sensible
  to serve, and the UI's load-more error path handles it.

This narrows an existing behaviour: `fetchPost(id)`'s offline fallback
scans the cache, so offline detail lookup now covers the first 20 posts
instead of all 100. That is an acceptable trade for a demo cache and it
must be stated in the class doc comment — caching accumulated pages is
listed as a non-goal precisely so this stays a small, honest change.

### State

A freezed state object, `presentation/posts_state.dart`:

```dart
@freezed
abstract class PostsState with _$PostsState {
  const factory PostsState({
    @Default(<Post>[]) List<Post> posts,
    @Default(true) bool hasMore,
    @Default(false) bool isLoadingMore,
    Object? loadMoreError,
  }) = _PostsState;
}
```

The controller becomes `AsyncNotifier<PostsState>`. The outer `AsyncValue`
keeps its current meaning — the **first** page's loading and error state,
which `AsyncValueWidget` already renders as a spinner or a full-screen
retry. The inner fields carry the **next** page's, which must never take
over the screen.

> **freezed `copyWith` cannot clear a nullable field**: passing `null`
> means "leave unchanged". Clearing `loadMoreError` therefore constructs a
> `PostsState` explicitly rather than calling `copyWith`. This is a real
> trap and the code carries a comment saying so.

### Controller

```dart
class PostsController extends AsyncNotifier<PostsState> {
  int _generation = 0;

  @override
  Future<PostsState> build() async {
    _generation++;                       // invalidates any in-flight loadMore
    final posts = await ref.watch(postsRepositoryProvider).fetchPosts();
    return PostsState(posts: posts, hasMore: posts.length >= postsPageSize);
  }

  Future<void> loadMore() async { /* guards, then append */ }

  Future<void> refresh() async { /* unchanged: invalidateSelf + swallow */ }
}
```

`loadMore()` returns immediately when there is no value yet, when
`isLoadingMore` is set, or when `hasMore` is false. It captures
`_generation` before awaiting and drops its result — success or failure —
if `_generation` moved while it was in flight.

The next page number is derived from what is already loaded
(`posts.length ~/ postsPageSize + 1`) rather than kept as a separate
counter, so the two cannot disagree.

### UI

`PostsScreen` becomes a `ConsumerStatefulWidget` holding a
`ScrollController`. Its listener calls `loadMore()` when
`position.pixels >= position.maxScrollExtent - 400`; the controller's own
guards make the repeated calls near the bottom harmless, which is the
point of putting the guard there rather than in the listener.

`ListView.separated` renders `posts.length + 1` items. The trailing item
is one of:

| Condition | Trailing item |
|---|---|
| `isLoadingMore` | Centered spinner + `postsLoadingMore` |
| `loadMoreError != null` | `postsLoadMoreError` + a `retry` button calling `loadMore()` |
| `!hasMore` | `postsEndOfList`, muted |
| otherwise | `SizedBox.shrink()` |

Pull-to-refresh keeps calling `refresh()`, which now also resets
pagination because `build()` re-runs from page 1.

## l10n keys

Added to `app_en.arb`, `app_ja.arb`, `app_ko.arb` (and regenerated):

| Key | en | ko | ja |
|---|---|---|---|
| `postsLoadingMore` | Loading more… | 더 불러오는 중… | さらに読み込み中… |
| `postsLoadMoreError` | Couldn't load more posts. | 게시글을 더 불러오지 못했습니다. | これ以上の投稿を読み込めませんでした。 |
| `postsEndOfList` | You've reached the end. | 마지막 게시글입니다. | 最後の投稿です。 |

The bottom retry button reuses the existing `retry` key. It is the same
word for the same action, and a second key would be duplication that can
drift; the criterion "the retry label exists in all three ARBs" is
satisfied by the key that is already there.

## Test plan

`test/features/posts/posts_controller_test.dart`:

1. `build` loads page 1 and sets `hasMore` when a full page returns.
2. `loadMore` appends page 2 and requests page 2, not page 1 again.
3. Two `loadMore` calls while the first is in flight → the repository is
   called **once**.
4. A short page sets `hasMore: false`, and a subsequent `loadMore` does
   not call the repository at all.
5. `refresh()` during an in-flight `loadMore` → the resolved page is
   dropped; the list is exactly page 1.
6. A failing `loadMore` keeps the existing posts and sets `loadMoreError`;
   a retry that succeeds appends and clears the error.
7. A failing **first** page still surfaces as `AsyncError` (existing
   behaviour must not regress).

`test/features/posts/posts_screen_test.dart`:

8. Scrolling to the bottom loads and renders the second page.
9. The end-of-list message renders once the last page is loaded.

`test/features/posts/cached_posts_repository_test.dart`:

10. Page 1 is cached and served on `NetworkException`; page 2 is not
    cached and its `NetworkException` propagates.

Existing fakes in four test files implement `PostsRepository` and must
adopt the new signature; `examples/todo_app` and `examples/weather_app`
carry the same feature and are re-synced.

## Acceptance criteria

Tracked on [#101][issue]; this spec does not restate them.

## Open questions

None.

[issue]: https://github.com/JoGyoungJun/fluFrame/issues/101
