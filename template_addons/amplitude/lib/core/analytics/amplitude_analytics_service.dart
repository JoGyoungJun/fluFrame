import 'dart:async';

import 'package:amplitude_flutter/amplitude.dart';
import 'package:amplitude_flutter/configuration.dart';
import 'package:amplitude_flutter/events/base_event.dart';
import 'package:fluframe_app/core/analytics/analytics_service.dart';

/// [AnalyticsService] backed by Amplitude.
///
/// Configuration comes from `--dart-define-from-file` (see `env/*.json`:
/// AMPLITUDE_API_KEY); with the key empty the app falls back to the
/// logging service instead of constructing this one.
class AmplitudeAnalyticsService implements AnalyticsService {
  /// Creates the service with [apiKey].
  AmplitudeAnalyticsService(String apiKey)
    : _amplitude = Amplitude(Configuration(apiKey: apiKey));

  final Amplitude _amplitude;

  @override
  void logEvent(String name, {Map<String, Object?> parameters = const {}}) {
    unawaited(
      _amplitude.track(
        BaseEvent(name, eventProperties: Map<String, dynamic>.from(parameters)),
      ),
    );
  }

  @override
  void logScreenView(String path) {
    unawaited(
      _amplitude.track(
        BaseEvent('screen_view', eventProperties: {'path': path}),
      ),
    );
  }
}
