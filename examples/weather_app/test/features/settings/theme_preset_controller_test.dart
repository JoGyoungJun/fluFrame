import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/core/storage/key_value_store.dart';
import 'package:weather_app/features/settings/presentation/theme_preset_controller.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ThemePresetController', () {
    test('starts from the initial override', () {
      final container = createContainer(
        overrides: [
          initialThemePresetProvider.overrideWithValue(ThemePreset.violet),
        ],
      );

      expect(container.read(themePresetProvider), ThemePreset.violet);
    });

    test('setThemePreset updates state and persists', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(themePresetProvider.notifier)
          .setThemePreset(ThemePreset.crimson);

      expect(container.read(themePresetProvider), ThemePreset.crimson);
      expect(await store.getString('settings.themePreset'), 'crimson');
    });
  });
}
