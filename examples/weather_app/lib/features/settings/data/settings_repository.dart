import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/core/storage/key_value_store.dart';

/// Persists user preferences (theme mode and locale) via a [KeyValueStore].
class SettingsRepository {
  /// Creates a repository backed by [store].
  SettingsRepository(KeyValueStore store) : _store = store;

  final KeyValueStore _store;

  static const String _themeModeKey = 'settings.themeMode';
  static const String _themePresetKey = 'settings.themePreset';
  static const String _localeKey = 'settings.locale';

  /// Loads the persisted [ThemeMode], defaulting to [ThemeMode.system].
  Future<ThemeMode> loadThemeMode() async {
    final raw = await _store.getString(_themeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => ThemeMode.system,
    );
  }

  /// Persists [mode] as the preferred theme mode.
  Future<void> saveThemeMode(ThemeMode mode) =>
      _store.setString(_themeModeKey, mode.name);

  /// Loads the persisted [ThemePreset], defaulting to [ThemePreset.indigo].
  Future<ThemePreset> loadThemePreset() async {
    final raw = await _store.getString(_themePresetKey);
    return ThemePreset.values.firstWhere(
      (preset) => preset.name == raw,
      orElse: () => ThemePreset.indigo,
    );
  }

  /// Persists [preset] as the preferred theme color.
  Future<void> saveThemePreset(ThemePreset preset) =>
      _store.setString(_themePresetKey, preset.name);

  /// Loads the persisted locale override, or `null` to follow the system.
  Future<Locale?> loadLocale() async {
    final raw = await _store.getString(_localeKey);
    return raw == null ? null : _parseLanguageTag(raw);
  }

  /// Persists [locale] as the locale override; `null` follows the system.
  ///
  /// The full language tag is stored so script and country subtags
  /// (e.g. `zh-Hant-TW`) survive a restart.
  Future<void> saveLocale(Locale? locale) => locale == null
      ? _store.remove(_localeKey)
      : _store.setString(_localeKey, locale.toLanguageTag());
}

Locale _parseLanguageTag(String tag) {
  final parts = tag.split('-');
  return switch (parts) {
    [final language] => Locale(language),
    [final language, final script] when script.length == 4 =>
      Locale.fromSubtags(languageCode: language, scriptCode: script),
    [final language, final country] => Locale(language, country),
    [final language, final script, final country] => Locale.fromSubtags(
      languageCode: language,
      scriptCode: script,
      countryCode: country,
    ),
    _ => Locale(parts.first),
  };
}

/// Provider for the app-wide [SettingsRepository].
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(keyValueStoreProvider)),
);
