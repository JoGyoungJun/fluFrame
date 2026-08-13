import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/app/router/app_router.dart';
import 'package:weather_app/app/theme/app_theme.dart';
import 'package:weather_app/features/settings/presentation/locale_controller.dart';
import 'package:weather_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:weather_app/features/settings/presentation/theme_preset_controller.dart';
import 'package:weather_app/l10n/gen/app_localizations.dart';

/// Root widget: wires the router, themes, and localization together.
class AppRoot extends ConsumerWidget {
  /// Creates the root app widget.
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final themePreset = ref.watch(themePresetProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: buildLightTheme(themePreset.seed),
      darkTheme: buildDarkTheme(themePreset.seed),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    );
  }
}
