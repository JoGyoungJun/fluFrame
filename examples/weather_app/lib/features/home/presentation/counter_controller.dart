import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The canonical Riverpod "hello world": a synchronous [Notifier].
class CounterController extends Notifier<int> {
  @override
  int build() => 0;

  /// Increments the counter by one.
  void increment() => state = state + 1;
}

/// Provider for the home screen counter.
final counterProvider = NotifierProvider<CounterController, int>(
  CounterController.new,
);
