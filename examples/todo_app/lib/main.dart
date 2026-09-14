import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/app/app.dart';
import 'package:todo_app/app/theme/app_theme.dart';
import 'package:todo_app/core/logging/error_handlers.dart';
import 'package:todo_app/core/network/api_exception.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/auth/data/auth_repository.dart';
import 'package:todo_app/features/auth/domain/user.dart';
import 'package:todo_app/features/auth/presentation/auth_controller.dart';
import 'package:todo_app/features/settings/data/settings_repository.dart';
import 'package:todo_app/features/settings/presentation/locale_controller.dart';
import 'package:todo_app/features/settings/presentation/theme_mode_controller.dart';
import 'package:todo_app/features/settings/presentation/theme_preset_controller.dart';

/// The persisted values the app resolves before its first frame.
typedef BootState = ({
  ThemeMode themeMode,
  ThemePreset themePreset,
  Locale? locale,
  User? initialUser,
});

/// How a failed boot read is reported. Matches [onPlatformError].
typedef ReportBootError = bool Function(Object error, StackTrace stackTrace);

/// Reads every persisted startup value from [store].
///
/// A read that fails falls back to its default and is reported through
/// [report] — [onPlatformError] in production — instead of propagating.
/// This runs before `runApp`, so an escaping storage error meant `runApp`
/// was never reached at all: a black screen, and the handlers installed
/// just above it have no widget tree to render the failure into. Booting
/// on defaults with the error in the crash report beats not booting.
///
/// [report] is injectable because both halves of that sentence are the
/// contract and only one of them used to be testable. Asserting the
/// fallback VALUES leaves the reporting call free to be deleted with the
/// suite still green — the app would boot on defaults with the storage
/// failure swallowed in total silence, which is the failure mode
/// `core/logging/error_handlers.dart` calls out as "vanish without a
/// trace".
Future<BootState> loadBootState(
  KeyValueStore store, {
  ReportBootError report = onPlatformError,
}) async {
  final settings = SettingsRepository(store);
  return (
    themeMode: await _orDefault(
      settings.loadThemeMode,
      ThemeMode.system,
      report,
    ),
    themePreset: await _orDefault(
      settings.loadThemePreset,
      ThemePreset.indigo,
      report,
    ),
    locale: await _orDefault<Locale?>(settings.loadLocale, null, report),
    initialUser: await _restoreSession(store, report),
  );
}

/// How long to wait before Riverpod retries a failed provider.
///
/// Riverpod 3 retries failing providers with exponential backoff by
/// default, which keeps AsyncValueWidget in its loading state for
/// ~40s before the error/retry UI ever appears. Typed API failures
/// are surfaced immediately; anything else gets one quick retry.
///
/// A named top-level function rather than a closure on the
/// [ProviderScope] below: every test builds its own scope (see
/// `test/helpers/helpers.dart`), so an inline closure is the one part of
/// the boot path no test can reach — the guard could invert and the suite
/// would stay green.
Duration? providerRetryPolicy(int retryCount, Object error) {
  if (error is ApiException || retryCount >= 1) return null;
  return const Duration(milliseconds: 200);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route every uncaught error through the two hooks in
  // core/logging/error_handlers.dart (the crash-reporting seam).
  FlutterError.onError = onFlutterError;
  WidgetsBinding.instance.platformDispatcher.onError = onPlatformError;

  // Resolve persisted settings before the first frame so the app starts
  // with the right theme, locale, and session (no flash of defaults).
  final store = SharedPreferencesKeyValueStore(SharedPreferencesAsync());
  final boot = await loadBootState(store);

  // runApp lives in a named closure so a crash-reporting addon can wrap
  // it (Sentry's `appRunner:`) and catch errors raised inside the zone,
  // which is impossible with a bare runApp call.
  void start() {
    runApp(
      ProviderScope(
        retry: providerRetryPolicy,
        overrides: [
          keyValueStoreProvider.overrideWithValue(store),
          initialThemeModeProvider.overrideWithValue(boot.themeMode),
          initialThemePresetProvider.overrideWithValue(boot.themePreset),
          initialLocaleProvider.overrideWithValue(boot.locale),
          initialUserProvider.overrideWithValue(boot.initialUser),
        ],
        child: const AppRoot(),
      ),
    );
  }

  start();
}

Future<T> _orDefault<T>(
  Future<T> Function() read,
  T fallback,
  ReportBootError report,
) async {
  try {
    return await read();
  } on Object catch (error, stackTrace) {
    report(error, stackTrace);
    return fallback;
  }
}

Future<User?> _restoreSession(
  KeyValueStore store,
  ReportBootError report,
) async {
  try {
    // Spelled out here instead of passed to [_orDefault] as a tear-off:
    // the `--backend` addons rewrite this exact expression when they swap
    // the auth repository, and an anchor they cannot find fails
    // generation.
    return await InMemoryAuthRepository(store).restoreSession();
  } on Object catch (error, stackTrace) {
    report(error, stackTrace);
    return null;
  }
}
