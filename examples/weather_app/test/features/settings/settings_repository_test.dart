import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/features/settings/data/settings_repository.dart';

import '../../helpers/helpers.dart';

void main() {
  group('SettingsRepository', () {
    late InMemoryKeyValueStore store;
    late SettingsRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = SettingsRepository(store);
    });

    test('loadThemeMode defaults to system when nothing is stored', () async {
      expect(await repository.loadThemeMode(), ThemeMode.system);
    });

    test('round-trips the theme mode', () async {
      await repository.saveThemeMode(ThemeMode.dark);

      expect(await repository.loadThemeMode(), ThemeMode.dark);
    });

    test('an unknown stored theme mode falls back to system', () async {
      // What a user who upgrades sees: the value on disk was written by an
      // older build and this one no longer has a mode by that name. It has
      // to boot on the default rather than throw from firstWhere.
      //
      // The storage key is spelled out rather than read from the
      // repository: it is the on-disk contract, and a test that took it
      // from the code under test could not notice it being renamed.
      await store.setString('settings.themeMode', 'nocturne');

      expect(await repository.loadThemeMode(), ThemeMode.system);
    });

    test('loadThemePreset defaults to indigo when nothing is stored', () async {
      expect(await repository.loadThemePreset(), ThemePreset.indigo);
    });

    test('round-trips the theme preset', () async {
      await repository.saveThemePreset(ThemePreset.emerald);

      expect(await repository.loadThemePreset(), ThemePreset.emerald);
    });

    test('an unknown stored theme preset falls back to indigo', () async {
      // Presets are persisted by name (see ThemePreset), so renaming or
      // dropping one leaves every installed app holding a value this build
      // cannot resolve — it must land on the default, not crash.
      await store.setString('settings.themePreset', 'sunset');

      expect(await repository.loadThemePreset(), ThemePreset.indigo);
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

    test('a stored script tag without a country survives', () async {
      // Four letters in the second position is a script, not a country:
      // read as Locale('zh', 'Hant') this would be a different locale, and
      // the app would fall back to English.
      await store.setString('settings.locale', 'zh-Hant');

      expect(
        await repository.loadLocale(),
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
    });

    test('extra subtags fall back to the language alone', () async {
      // BCP-47 allows extensions the parser does not model
      // (zh-Hant-TW-u-nu-latn). Dropping down to the language keeps the
      // user reading Chinese instead of losing the override entirely.
      await store.setString('settings.locale', 'zh-Hant-TW-u');

      expect(await repository.loadLocale(), const Locale('zh'));
    });

    test('saving a null locale clears the override', () async {
      await repository.saveLocale(const Locale('ko'));
      await repository.saveLocale(null);

      expect(await repository.loadLocale(), isNull);
    });

    test('never stores an empty language tag', () async {
      // The write half: clearing the override removes the key rather than
      // blanking it, so this repository never puts an unreadable tag on
      // disk itself. What happens when one gets there anyway is the read
      // half below — these two only make sense as a pair.
      await repository.saveLocale(const Locale('ko'));
      expect(await store.getString('settings.locale'), 'ko');

      await repository.saveLocale(null);
      expect(await store.getString('settings.locale'), isNull);
    });

    test('a blank stored language tag follows the system', () async {
      // The read half, and the one that was missing: no code path here
      // writes '', but the store is shared, and '' reaching the parser
      // matches its FIRST arm as Locale('') — which dart:ui asserts
      // against. main.dart's _orDefault catches that (`on Object`), so
      // the app still boots: the cost is a reported crash every launch
      // and a lost override, decided by a catch-all two layers up rather
      // than here. Every assertion above is on the write side, which is
      // what left the parser free to keep building that Locale.
      await store.setString('settings.locale', '');

      expect(await repository.loadLocale(), isNull);

      // Whitespace is not a language either, and reaches the same arm.
      await store.setString('settings.locale', '   ');

      expect(await repository.loadLocale(), isNull);
    });
  });
}
