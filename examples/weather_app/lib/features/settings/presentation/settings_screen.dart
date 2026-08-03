import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/features/settings/presentation/locale_controller.dart';
import 'package:weather_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:weather_app/features/settings/presentation/theme_preset_controller.dart';
import 'package:weather_app/l10n/gen/app_localizations.dart';

/// Lets the user pick the theme mode and language; both persist.
class SettingsScreen extends ConsumerWidget {
  /// Creates the settings screen.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            l10n.appearanceSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l10n.themeModeSystem),
                icon: const Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text(l10n.themeModeLight),
                icon: const Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text(l10n.themeModeDark),
                icon: const Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            onSelectionChanged: (selection) => unawaited(
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.colorSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final preset in ThemePreset.values)
                ChoiceChip(
                  avatar: CircleAvatar(
                    backgroundColor: preset.seed,
                    radius: 10,
                  ),
                  label: Text(_presetLabel(l10n, preset)),
                  selected: themePreset == preset,
                  onSelected: (_) => unawaited(
                    ref
                        .read(themePresetProvider.notifier)
                        .setThemePreset(preset),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            l10n.languageSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'system',
                label: Text(l10n.languageSystem),
              ),
              ButtonSegment(
                value: 'en',
                label: Text(l10n.languageEnglish),
              ),
              ButtonSegment(
                value: 'ko',
                label: Text(l10n.languageKorean),
              ),
            ],
            selected: {locale?.languageCode ?? 'system'},
            onSelectionChanged: (selection) {
              final code = selection.first;
              unawaited(
                ref
                    .read(localeProvider.notifier)
                    .setLocale(code == 'system' ? null : Locale(code)),
              );
            },
          ),
        ],
      ),
    );
  }

  String _presetLabel(AppLocalizations l10n, ThemePreset preset) {
    return switch (preset) {
      ThemePreset.indigo => l10n.presetIndigo,
      ThemePreset.emerald => l10n.presetEmerald,
      ThemePreset.crimson => l10n.presetCrimson,
      ThemePreset.amber => l10n.presetAmber,
      ThemePreset.violet => l10n.presetViolet,
    };
  }
}
