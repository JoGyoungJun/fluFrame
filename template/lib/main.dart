import 'package:fluframe_app/app/app.dart';
import 'package:fluframe_app/core/logging/error_handlers.dart';
import 'package:fluframe_app/core/network/api_exception.dart';
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/presentation/auth_controller.dart';
import 'package:fluframe_app/features/settings/data/settings_repository.dart';
import 'package:fluframe_app/features/settings/presentation/locale_controller.dart';
import 'package:fluframe_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:fluframe_app/features/settings/presentation/theme_preset_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route every uncaught error through the two hooks in
  // core/logging/error_handlers.dart (the crash-reporting seam).
  FlutterError.onError = onFlutterError;
  WidgetsBinding.instance.platformDispatcher.onError = onPlatformError;

  // Resolve persisted settings before the first frame so the app starts
  // with the right theme, locale, and session (no flash of defaults).
  final store = SharedPreferencesKeyValueStore(SharedPreferencesAsync());
  final settings = SettingsRepository(store);
  final themeMode = await settings.loadThemeMode();
  final themePreset = await settings.loadThemePreset();
  final locale = await settings.loadLocale();
  final initialUser = await InMemoryAuthRepository(store).restoreSession();

  // runApp lives in a named closure so a crash-reporting addon can wrap
  // it (Sentry's `appRunner:`) and catch errors raised inside the zone,
  // which is impossible with a bare runApp call.
  void start() {
    runApp(
      ProviderScope(
        // Riverpod 3 retries failing providers with exponential backoff by
        // default, which keeps AsyncValueWidget in its loading state for
        // ~40s before the error/retry UI ever appears. Typed API failures
        // are surfaced immediately; anything else gets one quick retry.
        retry: (retryCount, error) {
          if (error is ApiException || retryCount >= 1) return null;
          return const Duration(milliseconds: 200);
        },
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          initialThemeModeProvider.overrideWithValue(themeMode),
          initialThemePresetProvider.overrideWithValue(themePreset),
          initialLocaleProvider.overrideWithValue(locale),
          initialUserProvider.overrideWithValue(initialUser),
        ],
        child: const AppRoot(),
      ),
    );
  }

  start();
}
