import 'package:fluframe_app/app/router/app_router.dart';
import 'package:fluframe_app/app/theme/app_theme.dart';
import 'package:fluframe_app/features/settings/presentation/locale_controller.dart';
import 'package:fluframe_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Root widget: wires the router, themes, and localization together.
class FluFrameApp extends ConsumerWidget {
  /// Creates the root app widget.
  const FluFrameApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      routerConfig: router,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    );
  }
}
