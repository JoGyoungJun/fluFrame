import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/logging/error_handlers.dart';

void main() {
  group('error handlers', () {
    test('onFlutterError presents the details it was given', () {
      // The old test only asserted "does not throw", which an empty body
      // also satisfies. Spy on the sink instead.
      final presented = <FlutterErrorDetails>[];
      final original = FlutterError.presentError;
      addTearDown(() => FlutterError.presentError = original);
      FlutterError.presentError = presented.add;

      final details = FlutterErrorDetails(exception: Exception('boom'));
      onFlutterError(details);

      expect(presented, [same(details)]);
    });

    test('onPlatformError leaves the error unhandled', () {
      // `false` is the contract, not an implementation detail: it is what
      // keeps Flutter's default handler writing the error to the device
      // log. The app's only other sink is dart:developer, a VM service
      // channel absent from release builds — so returning `true` here
      // made every uncaught async error in production disappear.
      //
      // Invoked through a parameter of PlatformDispatcher.onError's exact
      // type, so the signature main.dart wires up is pinned here too.
      bool asPlatformHandler(bool Function(Object, StackTrace) handler) =>
          handler(Exception('boom'), StackTrace.current);

      expect(asPlatformHandler(onPlatformError), isFalse);
    });
  });
}
