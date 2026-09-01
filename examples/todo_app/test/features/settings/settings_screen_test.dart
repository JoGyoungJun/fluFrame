import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/settings/presentation/settings_screen.dart';
import 'package:todo_app/l10n/gen/app_localizations.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SettingsScreen', () {
    test('the picker offers exactly the locales the app supports', () {
      // Regression: the chip list was a hand-written literal beside a
      // generated supportedLocales and nothing compared them. Adding an
      // ARB grew one and not the other — a device locale the app honours
      // with no chip to pick it, or a chip that resolves to English while
      // claiming otherwise. language_labels_test.dart already reads the
      // generated list; this is the same move for the picker itself.
      //
      // Sets, not lists: the picker's order is a display choice and
      // gen-l10n emits supportedLocales alphabetically.
      final supported = {
        for (final locale in AppLocalizations.supportedLocales)
          locale.languageCode,
      };

      expect(languageCodes.toSet(), {'system', ...supported});
    });

    testWidgets('selecting Dark persists the theme mode', (tester) async {
      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(await store.getString('settings.themeMode'), 'dark');
    });

    testWidgets('selecting a color preset persists it', (tester) async {
      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await tester.tap(find.text('Emerald'));
      await tester.pumpAndSettle();

      expect(await store.getString('settings.themePreset'), 'emerald');
    });

    testWidgets('selecting the teal preset persists it', (tester) async {
      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await tester.tap(find.text('Teal'));
      await tester.pumpAndSettle();

      expect(await store.getString('settings.themePreset'), 'teal');
    });

    testWidgets('selecting a language persists the locale', (tester) async {
      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(await store.getString('settings.locale'), 'en');
    });

    // Regression: all three pickers fired their setter through
    // `unawaited`, so a store that refused the write threw into the zone —
    // where onPlatformError logs it and a release build shows the user
    // nothing. And because each controller sets `state` before it
    // persists, the chip stayed selected: the app read as if it had saved
    // a preference that the next launch would not have.
    //
    // One per surface, not one representative: the three call sites were
    // three separate `unawaited`s, and covering only one leaves the other
    // two free to regress.
    testWidgets('a theme mode that cannot be saved is reported', (
      tester,
    ) async {
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            FailingKeyValueStore(failWrites: true),
          ),
        ],
      );

      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Something went wrong.'), findsOneWidget);

      // Drain the snackbar's display timer: one still pending at teardown
      // fails the test.
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a color preset that cannot be saved is reported', (
      tester,
    ) async {
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            FailingKeyValueStore(failWrites: true),
          ),
        ],
      );

      await tester.tap(find.text('Emerald'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Something went wrong.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a language that cannot be saved is reported', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            FailingKeyValueStore(failWrites: true),
          ),
        ],
      );

      await tester.tap(find.text('English'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Something went wrong.'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a setting that saves reports nothing', (tester) async {
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('language labels stay on one line at phone width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // '한국어' is too short to ever wrap, so its height is the single-line
      // height for this text style. The selected segment is the one at risk.
      expect(
        tester.getSize(find.text('English')).height,
        tester.getSize(find.text('한국어')).height,
      );
    });

    testWidgets('content is capped on a wide window, the scrollable is not', (
      tester,
    ) async {
      // Design spec 005. The rows stop at 840 and centre; the ListView
      // itself still spans the window, so the mouse wheel works over the
      // gutters — which wrapping it in a ContentWidth would have broken.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      await tester.pumpAndSettle();

      final scrollable = tester.getRect(find.byType(Scrollable));
      expect(scrollable.left, 0);
      expect(scrollable.right, 1400);

      // 280 of centring inset plus the list's own 24 gutter.
      final section = tester.getRect(find.byType(SegmentedButton<ThemeMode>));
      expect(section.left, 304);
      expect(section.right, 1096);
    });

    testWidgets('nothing moves at phone width', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        const SettingsScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      await tester.pumpAndSettle();

      final section = tester.getRect(find.byType(SegmentedButton<ThemeMode>));
      expect(section.left, 24);
      expect(section.right, 366);
    });
  });
}
