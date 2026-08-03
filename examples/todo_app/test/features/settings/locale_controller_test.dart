import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/settings/presentation/locale_controller.dart';

import '../../helpers/helpers.dart';

void main() {
  group('LocaleController', () {
    test('starts from the initial override', () {
      final container = createContainer(
        overrides: [
          initialLocaleProvider.overrideWithValue(const Locale('ko')),
        ],
      );

      expect(container.read(localeProvider), const Locale('ko'));
    });

    test('setLocale updates state and persists', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('ko'));

      expect(container.read(localeProvider), const Locale('ko'));
      expect(await store.getString('settings.locale'), 'ko');
    });

    test('setLocale(null) clears the persisted override', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(localeProvider.notifier)
          .setLocale(const Locale('ko'));
      await container.read(localeProvider.notifier).setLocale(null);

      expect(container.read(localeProvider), isNull);
      expect(await store.getString('settings.locale'), isNull);
    });
  });
}
