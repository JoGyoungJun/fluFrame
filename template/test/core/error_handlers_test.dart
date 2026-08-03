import 'package:fluframe_app/core/logging/error_handlers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('error handlers', () {
    test('onPlatformError marks the error as handled', () {
      final handled = onPlatformError(
        Exception('boom'),
        StackTrace.current,
      );

      expect(handled, isTrue);
    });

    test('onFlutterError does not throw', () {
      // presentError prints to the console in tests — expected noise.
      expect(
        () => onFlutterError(
          FlutterErrorDetails(exception: Exception('boom')),
        ),
        returnsNormally,
      );
    });
  });
}
