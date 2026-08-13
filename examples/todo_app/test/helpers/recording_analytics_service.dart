import 'package:todo_app/core/analytics/analytics_service.dart';

/// [AnalyticsService] double that records every call for assertions.
class RecordingAnalyticsService implements AnalyticsService {
  /// Recorded events as `name` → last parameters.
  final List<(String, Map<String, Object?>)> events = [];

  /// Recorded screen-view paths, in order.
  final List<String> screenViews = [];

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {
    events.add((name, parameters));
  }

  @override
  void logScreenView(String path) => screenViews.add(path);
}
