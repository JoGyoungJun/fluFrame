import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/auth/data/auth_repository.dart';
import 'package:todo_app/l10n/gen/app_localizations.dart';

import 'in_memory_key_value_store.dart';

export 'in_memory_key_value_store.dart';

/// Tests always run against the in-memory auth repository, regardless of
/// which backend the app itself is wired to (`--backend` addons swap
/// `authRepositoryProvider` in lib/) — keeping the suite green and
/// offline after a backend swap.
final List<Override> _defaultOverrides = [
  authRepositoryProvider.overrideWith(
    (ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),
  ),
];

/// Overrides for full-app tests (`pumpWidget(ProviderScope(...))`):
/// in-memory storage plus the backend-agnostic auth pin.
List<Override> appTestOverrides({KeyValueStore? store}) => [
  keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
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
