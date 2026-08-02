import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

export 'in_memory_key_value_store.dart';

/// Creates a [ProviderContainer] that is disposed with the running test.
///
/// Riverpod 3's automatic retry is disabled so providers that intentionally
/// fail in a test stay failed instead of retrying in the background.
ProviderContainer createContainer({List<Override> overrides = const []}) {
  return ProviderContainer.test(
    overrides: overrides,
    retry: (retryCount, error) => null,
  );
}

/// Pumps [widget] inside a localized [MaterialApp] and a [ProviderScope].
extension PumpApp on WidgetTester {
  /// See [PumpApp].
  Future<void> pumpApp(
    Widget widget, {
    List<Override> overrides = const [],
  }) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (retryCount, error) => null,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
  }
}
