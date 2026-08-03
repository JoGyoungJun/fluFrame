import 'package:fluframe_app/core/analytics/analytics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The canonical Riverpod "hello world": a synchronous [Notifier].
class CounterController extends Notifier<int> {
  @override
  int build() => 0;

  /// Increments the counter by one (and demonstrates event tracking).
  void increment() {
    state = state + 1;
    ref
        .read(analyticsServiceProvider)
        .logEvent('counter_incremented', parameters: {'value': state});
  }
}

/// Provider for the home screen counter.
final counterProvider = NotifierProvider<CounterController, int>(
  CounterController.new,
);
