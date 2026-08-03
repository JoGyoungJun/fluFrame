import 'package:flutter/material.dart';

/// Selectable seed-color presets for the app theme.
///
/// Persisted by name (see `SettingsRepository`), so reordering is safe
/// but renaming a value is a breaking change for stored settings.
enum ThemePreset {
  /// Default blue.
  indigo(Color(0xFF2563EB)),

  /// Green.
  emerald(Color(0xFF059669)),

  /// Red.
  crimson(Color(0xFFDC2626)),

  /// Orange.
  amber(Color(0xFFD97706)),

  /// Purple.
  violet(Color(0xFF7C3AED));

  const ThemePreset(this.seed);

  /// Seed color fed into [ColorScheme.fromSeed].
  final Color seed;
}

/// Builds the light [ThemeData] for the app from [seed].
ThemeData buildLightTheme(Color seed) => _buildTheme(seed, Brightness.light);

/// Builds the dark [ThemeData] for the app from [seed].
ThemeData buildDarkTheme(Color seed) => _buildTheme(seed, Brightness.dark);

ThemeData _buildTheme(Color seed, Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colorScheme,
    appBarTheme: const AppBarThemeData(centerTitle: true),
  );
}
