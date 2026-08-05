import 'dart:async';

import 'package:fluframe_app/app/theme/app_theme.dart';
import 'package:fluframe_app/features/settings/presentation/locale_controller.dart';
import 'package:fluframe_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:fluframe_app/features/settings/presentation/theme_preset_controller.dart';
import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel for "follow the device locale" in the language picker.
const String _systemLanguage = 'system';

/// Language codes offered in settings, in display order.
const List<String> _languageCodes = [_systemLanguage, 'en', 'ko', 'ja'];

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
          Wrap(
            spacing: 8,
            children: [
              for (final code in _languageCodes)
                ChoiceChip(
                  label: Text(_languageLabel(l10n, code)),
                  selected: (locale?.languageCode ?? _systemLanguage) == code,
                  onSelected: (_) => unawaited(
                    ref
                        .read(localeProvider.notifier)
                        .setLocale(
                          code == _systemLanguage ? null : Locale(code),
                        ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _languageLabel(AppLocalizations l10n, String code) {
    return switch (code) {
      'en' => l10n.languageEnglish,
      'ko' => l10n.languageKorean,
      'ja' => l10n.languageJapanese,
      _ => l10n.languageSystem,
    };
  }

  String _presetLabel(AppLocalizations l10n, ThemePreset preset) {
    return switch (preset) {
      ThemePreset.indigo => l10n.presetIndigo,
      ThemePreset.emerald => l10n.presetEmerald,
      ThemePreset.crimson => l10n.presetCrimson,
      ThemePreset.amber => l10n.presetAmber,
      ThemePreset.violet => l10n.presetViolet,
      ThemePreset.teal => l10n.presetTeal,
    };
  }
}
