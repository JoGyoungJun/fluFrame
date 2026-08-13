import 'dart:async';

import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/features/posts/data/posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';
import 'package:fluframe_app/features/posts/presentation/posts_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Serves generated pages and records what was asked for.
class _PagingRepository implements PostsRepository {
  _PagingRepository({this.total = postsPageSize * 2});

  /// How many posts exist in total.
  int total;

  /// Every page number requested, in order.
  final requestedPages = <int>[];

  /// When set, the next fetch of this page throws instead of returning.
  int? failPage;

  /// When set, fetches wait on this before returning.
  Completer<void>? gate;

  @override
  Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = postsPageSize,
  }) async {
    requestedPages.add(page);
    if (gate != null) await gate!.future;
    if (failPage == page) {
      failPage = null;
      throw const NetworkException('down');
    }
    final start = (page - 1) * limit;
    return [
      for (var id = start + 1; id <= total && id <= start + limit; id++)
        Post(id: id, userId: 1, title: 'post $id', body: 'body $id'),
    ];
  }

  @override
  Future<Post> fetchPost(int id) async =>
      Post(id: id, userId: 1, title: 'post $id', body: 'body $id');
}

ProviderContainer _containerFor(_PagingRepository repository) =>
    createContainer(
      overrides: [postsRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  group('PostsController.build', () {
    test('loads the first page and reports that more exist', () async {
      final repository = _PagingRepository();
      final container = _containerFor(repository);

      final state = await container.read(postsControllerProvider.future);

      expect(repository.requestedPages, [1]);
      expect(state.posts, hasLength(postsPageSize));
      expect(state.posts.first.id, 1);
      expect(state.hasMore, isTrue);
      expect(state.isLoadingMore, isFalse);
    });

    test('a failing first page still surfaces as AsyncError', () async {
      // The next-page error path must not swallow the one that owns the
      // whole screen.
      final repository = _PagingRepository()..failPage = 1;
      final container = _containerFor(repository);

      await expectLater(
        container.read(postsControllerProvider.future),
        throwsA(isA<Exception>()),
      );
      expect(container.read(postsControllerProvider).hasError, isTrue);
    });
  });

  group('PostsController.loadMore', () {
    test('appends the next page', () async {
      final repository = _PagingRepository();
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);

      await container.read(postsControllerProvider.notifier).loadMore();

      final state = container.read(postsControllerProvider).requireValue;
      expect(repository.requestedPages, [1, 2]);
      expect(state.posts, hasLength(postsPageSize * 2));
      expect(state.posts.last.id, postsPageSize * 2);
      expect(
        state.hasMore,
        isTrue,
        reason: 'a full page cannot be told apart from a middle one',
      );
    });

    test(
      'an empty page ends a list whose length is an exact multiple',
      () async {
        // total == 2 pages exactly, so page 2 comes back full and the end is
        // only discovered by asking for a third page and getting nothing.
        final repository = _PagingRepository();
        final container = _containerFor(repository);
        await container.read(postsControllerProvider.future);
        final notifier = container.read(postsControllerProvider.notifier);

        await notifier.loadMore();
        await notifier.loadMore();

        final state = container.read(postsControllerProvider).requireValue;
        expect(repository.requestedPages, [1, 2, 3]);
        expect(state.posts, hasLength(postsPageSize * 2));
        expect(state.hasMore, isFalse);
      },
    );

    test('a second call while one is in flight is dropped', () async {
      // The scroll listener fires every frame near the bottom; without the
      // guard each frame would start another request for the same page.
      final repository = _PagingRepository();
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);

      final gate = Completer<void>();
      repository
        ..gate = gate
        ..requestedPages.clear();
      final notifier = container.read(postsControllerProvider.notifier);
      final first = notifier.loadMore();
      final second = notifier.loadMore();
      gate.complete();
      await Future.wait([first, second]);

      expect(repository.requestedPages, [2]);
    });

    test('stops at a short page and never asks again', () async {
      final repository = _PagingRepository(total: postsPageSize + 5);
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);
      final notifier = container.read(postsControllerProvider.notifier);

      await notifier.loadMore();
      expect(
        container.read(postsControllerProvider).requireValue.hasMore,
        isFalse,
      );

      repository.requestedPages.clear();
      await notifier.loadMore();

      expect(repository.requestedPages, isEmpty);
    });

    test('a failure keeps the loaded posts and retry appends', () async {
      final repository = _PagingRepository(total: postsPageSize * 3)
        ..failPage = 2;
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);
      final notifier = container.read(postsControllerProvider.notifier);

      await notifier.loadMore();

      var state = container.read(postsControllerProvider).requireValue;
      expect(state.posts, hasLength(postsPageSize), reason: 'page 1 survives');
      expect(state.loadMoreError, isA<NetworkException>());
      expect(state.isLoadingMore, isFalse);
      expect(state.hasMore, isTrue, reason: 'a failure is not the end');

      await notifier.loadMore();

      state = container.read(postsControllerProvider).requireValue;
      expect(state.posts, hasLength(postsPageSize * 2));
      expect(state.loadMoreError, isNull);
    });

    test('a page resolving after a refresh is dropped', () async {
      // ref.invalidate reuses this notifier and leaves it mounted, so the
      // late write succeeds unless the generation guard rejects it — the
      // list would otherwise become [stale page 1, page 2].
      final repository = _PagingRepository();
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);
      final notifier = container.read(postsControllerProvider.notifier);

      final gate = Completer<void>();
      repository.gate = gate;
      final pending = notifier.loadMore();

      repository.gate = null;
      await notifier.refresh();
      gate.complete();
      await pending;

      final state = container.read(postsControllerProvider).requireValue;
      expect(state.posts, hasLength(postsPageSize));
      expect(state.posts.last.id, postsPageSize);
      expect(state.isLoadingMore, isFalse);
    });
  });

  group('PostsController.refresh', () {
    test('does not throw when the fetch fails', () async {
      // Regression: refresh() used to rethrow, and RefreshIndicator
      // discards onRefresh errors — every failed pull-to-refresh became
      // an unhandled async exception.
      final repository = _PagingRepository();
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);

      repository.failPage = 1;
      await container.read(postsControllerProvider.notifier).refresh();

      expect(container.read(postsControllerProvider).hasError, isTrue);
    });

    test('goes back to page one', () async {
      final repository = _PagingRepository(total: postsPageSize * 3);
      final container = _containerFor(repository);
      await container.read(postsControllerProvider.future);
      final notifier = container.read(postsControllerProvider.notifier);
      await notifier.loadMore();

      await notifier.refresh();

      final state = container.read(postsControllerProvider).requireValue;
      expect(state.posts, hasLength(postsPageSize));
      expect(state.hasMore, isTrue);
    });
  });

  group('postProvider', () {
    test('fetches the post matching the id', () async {
      final container = _containerFor(_PagingRepository());

      final post = await container.read(postProvider(1).future);

      expect(post.id, 1);
    });
  });
}
