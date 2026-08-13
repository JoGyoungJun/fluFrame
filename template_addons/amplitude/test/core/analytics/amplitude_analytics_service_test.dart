import 'package:fluframe_app/core/analytics/amplitude_analytics_service.dart';
import 'package:fluframe_app/core/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

// Ships with the `--analytics amplitude` addon and runs inside the
// generated app, the only place amplitude_flutter resolves. No SDK client
// is ever constructed here, so nothing tries to reach Amplitude.
void main() {
  group('analyticsServiceProvider', () {
    test('falls back to logging while AMPLITUDE_API_KEY is empty', () {
      final container = createContainer();

      final service = container.read(analyticsServiceProvider);

      // Constructing the Amplitude client with an empty key builds a
      // service that can never deliver an event, on every run of a freshly
      // generated app — the committed env/*.json ship the key empty.
      expect(service, isA<LoggingAnalyticsService>());
      expect(service, isNot(isA<AmplitudeAnalyticsService>()));
    });

    test('the logging fallback still accepts events', () {
      final service = createContainer().read(analyticsServiceProvider);

      // The seam has to stay usable unconfigured: screen views are logged
      // by the router listener on every navigation, so a fallback that
      // threw would take the app down instead of the analytics.
      expect(() => service.logEvent('checkout_completed'), returnsNormally);
      expect(() => service.logScreenView('/home'), returnsNormally);
    });
  });
}
