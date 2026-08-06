import 'package:fluframe_app/app/theme/app_theme.dart';
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:fluframe_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/helpers.dart';

/// Storage that fails every operation, the way a corrupted preferences
/// file or a platform channel that never answers does.
class _FailingKeyValueStore implements KeyValueStore {
  @override
  Future<String?> getString(String key) async =>
      throw StateError('storage unavailable');

  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('storage unavailable');

  @override
  Future<void> remove(String key) async =>
      throw StateError('storage unavailable');
}

void main() {
  group('loadBootState', () {
    test('falls back to defaults when storage fails', () async {
      // Regression: these reads happen before runApp, so one failing read
      // used to take the entire boot down — runApp was never reached and
      // the app opened on a black screen that the error handlers
      // installed moments earlier had no widget tree to draw into.
      final boot = await loadBootState(_FailingKeyValueStore());

      expect(boot.themeMode, ThemeMode.system);
      expect(boot.themePreset, ThemePreset.indigo);
      expect(boot.locale, isNull);
      expect(boot.initialUser, isNull);
    });

    test('returns the persisted values when storage works', () async {
      final store = InMemoryKeyValueStore();
      await store.setString('settings.themeMode', 'dark');
      await store.setString('settings.themePreset', 'emerald');
      await store.setString('settings.locale', 'ko');
      await store.setString('auth.session.email', 'dev@example.com');

      final boot = await loadBootState(store);

      expect(boot.themeMode, ThemeMode.dark);
      expect(boot.themePreset, ThemePreset.emerald);
      expect(boot.locale, const Locale('ko'));
      expect(boot.initialUser, const User(email: 'dev@example.com'));
    });
  });
}
