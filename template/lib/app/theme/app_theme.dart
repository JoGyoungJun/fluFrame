import 'package:flutter/material.dart';

const Color _seedColor = Color(0xFF2563EB);

/// Builds the light [ThemeData] for the app.
ThemeData buildLightTheme() => _buildTheme(Brightness.light);

/// Builds the dark [ThemeData] for the app.
ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: _seedColor,
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: colorScheme,
    appBarTheme: const AppBarThemeData(centerTitle: true),
  );
}
