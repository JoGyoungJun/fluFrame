import 'package:fluframe_app/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Theme mode resolved from storage before `runApp` (see `main.dart`).
///
/// Overridden in the root `ProviderScope` so the first frame already uses
/// the persisted value — no light/dark flash on startup.
final initialThemeModeProvider = Provider<ThemeMode>(
  (ref) => ThemeMode.system,
);

/// Controls the app-wide [ThemeMode] and persists changes.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(initialThemeModeProvider);

  /// Applies [mode] immediately and persists it for the next launch.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await ref.read(settingsRepositoryProvider).saveThemeMode(mode);
  }
}

/// Provider for the app-wide [ThemeModeController].
final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
