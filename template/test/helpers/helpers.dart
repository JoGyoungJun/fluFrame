import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/posts/data/posts_repository.dart';
import 'package:fluframe_app/features/posts/domain/post.dart';
import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'in_memory_key_value_store.dart';

export 'failing_key_value_store.dart';
export 'in_memory_key_value_store.dart';
export 'recording_analytics_service.dart';

/// Tests always run against the in-memory auth repository, regardless of
/// which backend the app itself is wired to (`--backend` addons swap
/// `authRepositoryProvider` in lib/) — keeping the suite green and
/// offline after a backend swap.
final List<Override> _defaultOverrides = [
  authRepositoryProvider.overrideWith(
    (ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),
  ),
];

/// Answers posts from memory, so a route test never reaches the network.
///
/// Navigating anywhere under `/home/posts` builds the posts list on the
/// way to the leaf, and the real repository starts a Dio request that no
/// test environment completes — leaving a pending timer that fails the
/// test at teardown (#158). A test that wants specific posts behaviour
/// overrides this again with its own fake.
class InMemoryPostsRepository implements PostsRepository {
  @override
  Future<List<Post>> fetchPosts({
    int page = 1,
    int limit = postsPageSize,
  }) async => const [];

  @override
  Future<Post> fetchPost(int id) async =>
      Post(id: id, userId: 1, title: 'Post $id', body: 'body $id');
}

/// Overrides for full-app tests (`pumpWidget(ProviderScope(...))`):
/// in-memory storage, the backend-agnostic auth pin, and a posts
/// repository that cannot reach the network.
List<Override> appTestOverrides({KeyValueStore? store}) => [
  keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
  postsRepositoryProvider.overrideWithValue(InMemoryPostsRepository()),
  ..._defaultOverrides,
];

/// Creates a [ProviderContainer] that is disposed with the running test.
///
/// Riverpod 3's automatic retry is disabled so providers that intentionally
/// fail in a test stay failed instead of retrying in the background.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  return ProviderContainer.test(
    overrides: [..._defaultOverrides, ...overrides],
    retry: (retryCount, error) => null,
  );
}

/// Pumps [widget] inside a localized [MaterialApp] and a [ProviderScope].
extension PumpApp on WidgetTester {
  /// See [PumpApp].
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: [..._defaultOverrides, ...overrides],
        retry: (retryCount, error) => null,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
  }
}
