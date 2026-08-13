/// Global error hooks, wired in `main.dart` before `runApp`.
///
/// **Crash reporting seam**: to ship errors to Sentry, Crashlytics, or
/// any other service, add the SDK call inside the two handlers below —
/// every uncaught error in the app flows through exactly these two
/// functions.
library;

import 'package:flutter/foundation.dart';
import 'package:todo_app/core/logging/app_logger.dart';

const AppLogger _logger = AppLogger('todo_app.errors');

/// Handles errors thrown by the Flutter framework (build/layout/paint).
///
/// Presents the error like the default handler (red screen in debug),
/// then records it.
void onFlutterError(FlutterErrorDetails details) {
  FlutterError.presentError(details);
  _logger.error(
    'Flutter framework error',
    details.exception,
    details.stack,
  );
}

/// Handles uncaught asynchronous errors from the platform dispatcher.
///
/// Returns `false` — "not handled" — on purpose, so Flutter's default
/// handler still writes the error to the device log (logcat, Console).
/// The only sink above is [AppLogger], which goes through
/// `dart:developer`: a VM-service channel that does not exist in a
/// release build. Claiming the error as handled there made every
/// uncaught async error in production vanish without a trace.
///
/// Return `true` here only once a real reporter — Sentry, Crashlytics —
/// is wired in above and has actually accepted the error.
bool onPlatformError(Object error, StackTrace stackTrace) {
  _logger.error('Uncaught platform error', error, stackTrace);
  return false;
}
