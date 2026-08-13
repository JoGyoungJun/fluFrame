import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/features/settings/data/settings_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository repository;

    setUp(() {
      repository = SettingsRepository(InMemoryKeyValueStore());
    });

    test('loadThemeMode defaults to system when nothing is stored', () async {
      expect(await repository.loadThemeMode(), ThemeMode.system);
    });

    test('round-trips the theme mode', () async {
      await repository.saveThemeMode(ThemeMode.dark);

      expect(await repository.loadThemeMode(), ThemeMode.dark);
    });

    test('loadThemePreset defaults to indigo when nothing is stored', () async {
      expect(await repository.loadThemePreset(), ThemePreset.indigo);
    });

    test('round-trips the theme preset', () async {
      await repository.saveThemePreset(ThemePreset.emerald);

      expect(await repository.loadThemePreset(), ThemePreset.emerald);
    });

    test('loadLocale defaults to null when nothing is stored', () async {
      expect(await repository.loadLocale(), isNull);
    });

    test('round-trips the locale override', () async {
      await repository.saveLocale(const Locale('ko'));

      expect(await repository.loadLocale(), const Locale('ko'));
    });

    test('round-trips script and country subtags', () async {
      // Regression: persisting only languageCode silently degraded
      // zh-Hant-TW to zh after a restart.
      const traditionalChinese = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
        countryCode: 'TW',
      );
      await repository.saveLocale(traditionalChinese);
      expect(await repository.loadLocale(), traditionalChinese);

      const brazilianPortuguese = Locale('pt', 'BR');
      await repository.saveLocale(brazilianPortuguese);
      expect(await repository.loadLocale(), brazilianPortuguese);
    });

    test('saving a null locale clears the override', () async {
      await repository.saveLocale(const Locale('ko'));
      await repository.saveLocale(null);

      expect(await repository.loadLocale(), isNull);
    });
  });
}
