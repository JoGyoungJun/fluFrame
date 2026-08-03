/// Global error hooks, wired in `main.dart` before `runApp`.
///
/// **Crash reporting seam**: to ship errors to Sentry, Crashlytics, or
/// any other service, add the SDK call inside the two handlers below —
/// every uncaught error in the app flows through exactly these two
/// functions.
library;

import 'package:fluframe_app/core/logging/app_logger.dart';
import 'package:flutter/foundation.dart';

const AppLogger _logger = AppLogger('fluframe_app.errors');

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
/// Returning `true` marks the error as handled so it is not rethrown.
bool onPlatformError(Object error, StackTrace stackTrace) {
  _logger.error('Uncaught platform error', error, stackTrace);
  return true;
}
