import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

void main() {
  group('ThemeModeController', () {
    test('starts from the initial override', () {
      final container = createContainer(
        overrides: [
          initialThemeModeProvider.overrideWithValue(ThemeMode.dark),
        ],
      );

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    test('setThemeMode updates state and persists', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(themeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(themeModeProvider), ThemeMode.dark);
      expect(await store.getString('settings.themeMode'), 'dark');
    });
  });
}
