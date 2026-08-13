import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/features/settings/data/settings_repository.dart';

/// Theme preset resolved from storage before `runApp` (see `main.dart`).
final initialThemePresetProvider = Provider<ThemePreset>(
  (ref) => ThemePreset.indigo,
);

/// Controls the app-wide [ThemePreset] and persists changes.
class ThemePresetController extends Notifier<ThemePreset> {
  @override
  ThemePreset build() => ref.watch(initialThemePresetProvider);

  /// Applies [preset] immediately and persists it for the next launch.
  Future<void> setThemePreset(ThemePreset preset) async {
    state = preset;
    await ref.read(settingsRepositoryProvider).saveThemePreset(preset);
  }
}

/// Provider for the app-wide [ThemePresetController].
final themePresetProvider =
    NotifierProvider<ThemePresetController, ThemePreset>(
      ThemePresetController.new,
    );
