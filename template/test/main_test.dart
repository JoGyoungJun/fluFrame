import 'package:fluframe_app/app/theme/app_theme.dart';
import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:fluframe_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/helpers.dart';

void main() {
  group('loadBootState', () {
    test('falls back to defaults when storage fails', () async {
      // Regression: these reads happen before runApp, so one failing read
      // used to take the entire boot down — runApp was never reached and
      // the app opened on a black screen that the error handlers
      // installed moments earlier had no widget tree to draw into.
      final boot = await loadBootState(
        FailingKeyValueStore(
          failReads: true,
          failWrites: true,
          failRemovals: true,
        ),
      );

      expect(boot.themeMode, ThemeMode.system);
      expect(boot.themePreset, ThemePreset.indigo);
      expect(boot.locale, isNull);
      expect(boot.initialUser, isNull);
    });

    test('one unreadable key does not cost the other three', () async {
      // The four reads are guarded individually, and that is the whole
      // point of the shape: collapsing them into one try/catch around the
      // record passes both tests above (all fail -> all defaults; all
      // succeed -> all values) while a user with one corrupt entry
      // silently loses their theme, their colour preset AND their signed-in
      // session as well.
      final store = FailingKeyValueStore(
        failReads: true,
        failKeys: const {'settings.themeMode'},
      );
      await store.setString('settings.themePreset', 'emerald');
      await store.setString('settings.locale', 'ko');
      await store.setString('auth.session.email', 'dev@example.com');

      final boot = await loadBootState(store);

      expect(boot.themeMode, ThemeMode.system, reason: 'the failing read');
      expect(boot.themePreset, ThemePreset.emerald);
      expect(boot.locale, const Locale('ko'));
      expect(boot.initialUser, const User(email: 'dev@example.com'));
    });

    test('every failed read reaches the crash report', () async {
      // The other half of loadBootState's contract: "Booting on defaults
      // with the error in the crash report beats not booting." Only the
      // defaults half was tested, so deleting the reporting call left the
      // suite green while a storage failure vanished without a trace —
      // the exact outcome core/logging/error_handlers.dart exists to
      // prevent.
      final reported = <Object>[];

      final boot = await loadBootState(
        FailingKeyValueStore(
          failReads: true,
          failWrites: true,
          failRemovals: true,
        ),
        report: (error, stackTrace) {
          reported.add(error);
          return true;
        },
      );

      expect(
        reported,
        hasLength(4),
        reason: 'all four reads failed, so all four must be reported',
      );
      // Still booted, on defaults — reporting must not cost the fallback.
      expect(boot.themeMode, ThemeMode.system);
      expect(boot.initialUser, isNull);
    });

    test('one unreadable key reports exactly one error', () async {
      // Pins the per-read shape from the reporting side, the way the test
      // above it pins the value side: one try/catch around the whole
      // record would report a single error and lose three settings.
      final reported = <Object>[];
      final store = FailingKeyValueStore(
        failReads: true,
        failKeys: const {'settings.themeMode'},
      );
      await store.setString('settings.themePreset', 'emerald');
      await store.setString('settings.locale', 'ko');
      await store.setString('auth.session.email', 'dev@example.com');

      final boot = await loadBootState(
        store,
        report: (error, stackTrace) {
          reported.add(error);
          return true;
        },
      );

      expect(reported, hasLength(1));
      expect(boot.themePreset, ThemePreset.emerald);
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

  group('providerRetryPolicy', () {
    // Regression: this policy lived as an inline closure on the
    // ProviderScope in main(), and every test builds its own scope — so
    // nothing in the suite ever evaluated it. Inverting the guard, or
    // dropping the retry entirely, stayed green. These read the function
    // directly, which is why it had to become one.
    test('does not retry a typed API failure', () {
      expect(
        providerRetryPolicy(0, const NetworkException('offline')),
        isNull,
      );
    });

    test('retries an untyped failure once, quickly', () {
      expect(
        providerRetryPolicy(0, StateError('boom')),
        const Duration(milliseconds: 200),
      );
    });

    test('gives up on an untyped failure after that one retry', () {
      expect(providerRetryPolicy(1, StateError('boom')), isNull);
    });
  });
}
