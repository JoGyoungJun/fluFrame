import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/analytics/analytics_service.dart';
import 'package:weather_app/features/home/presentation/counter_controller.dart';

import '../../helpers/helpers.dart';

void main() {
  group('CounterController', () {
    test('starts at zero', () {
      final container = createContainer();

      expect(container.read(counterProvider), 0);
    });

    test('increment increases state by one', () {
      final container = createContainer();

      container.read(counterProvider.notifier).increment();

      expect(container.read(counterProvider), 1);
    });

    test('increment reports the analytics event', () {
      final analytics = RecordingAnalyticsService();
      final container = createContainer(
        overrides: [
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );

      container.read(counterProvider.notifier).increment();

      expect(analytics.events.single.$1, 'counter_incremented');
      expect(analytics.events.single.$2, {'value': 1});
    });
  });
}
