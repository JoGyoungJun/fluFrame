import 'package:fluframe_app/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Locale override resolved from storage before `runApp` (see `main.dart`).
///
/// `null` means "follow the system locale".
final initialLocaleProvider = Provider<Locale?>((ref) => null);

/// Controls the app-wide locale override and persists changes.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => ref.watch(initialLocaleProvider);

  /// Applies [locale] immediately and persists it; `null` follows the system.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    await ref.read(settingsRepositoryProvider).saveLocale(locale);
  }
}

/// Provider for the app-wide [LocaleController].
final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
