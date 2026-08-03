import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/storage/key_value_store.dart';
import 'package:weather_app/features/settings/presentation/settings_screen.dart';

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
  });
}
