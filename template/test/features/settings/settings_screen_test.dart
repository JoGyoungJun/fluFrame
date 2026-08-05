import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SettingsScreen', () {
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
  });
}
