import 'package:fluframe_app/core/logging/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Product analytics seam.
///
/// The app reports screen views (automatically, via the router listener
/// in `app_router.dart`) and domain events through this interface —
/// never through an SDK directly. Swap [analyticsServiceProvider] to
/// wire a real service (`--analytics` addons do exactly that).
abstract interface class AnalyticsService {
  /// Records a domain event, e.g. `logEvent('checkout_completed')`.
  void logEvent(String name, {Map<String, Object?> parameters});

  /// Records that [path] became the visible screen.
  void logScreenView(String path);
}

/// Default [AnalyticsService]: writes events to the debug log only.
///
/// Keeps the template dependency-free while making the event stream
/// visible during development.
class LoggingAnalyticsService implements AnalyticsService {
  /// Creates the logging service.
  const LoggingAnalyticsService();

  static const AppLogger _logger = AppLogger('fluframe_app.analytics');

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {
    _logger.debug(
      parameters.isEmpty ? 'event: $name' : 'event: $name $parameters',
    );
  }

  @override
  void logScreenView(String path) => _logger.debug('screen: $path');
}

/// Provider for the app-wide [AnalyticsService] — the swap point for
/// real analytics backends.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => const LoggingAnalyticsService(),
);
