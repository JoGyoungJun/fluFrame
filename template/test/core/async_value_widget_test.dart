import 'dart:async';

import 'package:fluframe_app/core/widgets/async_value_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/helpers.dart';

/// The states this widget has to tell apart — loading over an error,
/// an error over data — are only reachable through a real rebuild, so
/// the tests drive a provider instead of hand-building an [AsyncValue].
FutureProvider<String> _providerYielding(List<Future<String> Function()> runs) {
  var attempt = 0;
  return FutureProvider<String>((ref) => runs[attempt++]());
}

Future<String> _pending() => Completer<String>().future;

Future<String> _down() => Future<String>.error(Exception('down'));

void main() {
  group('AsyncValueWidget', () {
    Future<void> pump(WidgetTester tester, AsyncValue<String> value) =>
        tester.pumpApp(
          AsyncValueWidget<String>(
            value: value,
            onRetry: () {},
            messageOf: (error) => 'Failed to load.',
            data: Text.new,
          ),
        );

    testWidgets('spins while the first load runs', (tester) async {
      await pump(tester, const AsyncLoading<String>());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders the data', (tester) async {
      await pump(tester, const AsyncData<String>('hello'));

      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('shows the error view when nothing loaded', (tester) async {
      await pump(
        tester,
        AsyncError<String>(Exception('down'), StackTrace.empty),
      );

      expect(find.text('Failed to load.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('spins while a retry after an error is in flight', (
      tester,
    ) async {
      // Regression: an invalidation leaves the previous AsyncError in
      // place with `isLoading` set, so matching on the sealed type kept
      // the error view on screen and a Retry tap looked like nothing had
      // happened — users tapped again, duplicating the request.
      final provider = _providerYielding([_down, _pending]);
      final container = createContainer();
      await expectLater(
        container.read(provider.future),
        throwsA(isA<Exception>()),
      );
      container.invalidate(provider);

      await pump(tester, container.read(provider));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('keeps the loaded data when a refresh fails', (tester) async {
      // Regression: a failed pull-to-refresh is an AsyncError that still
      // carries the last data, and the full-screen error view threw away
      // the list the user was reading.
      final provider = _providerYielding([() async => 'hello', _down]);
      final container = createContainer();
      expect(await container.read(provider.future), 'hello');
      container.invalidate(provider);
      await expectLater(
        container.read(provider.future),
        throwsA(isA<Exception>()),
      );

      await pump(tester, container.read(provider));

      expect(find.text('hello'), findsOneWidget);
      expect(find.text('Failed to load.'), findsNothing);
    });

    testWidgets('keeps the loaded data while a refresh runs', (tester) async {
      final provider = _providerYielding([() async => 'hello', _pending]);
      final container = createContainer();
      expect(await container.read(provider.future), 'hello');
      container.invalidate(provider);

      await pump(tester, container.read(provider));

      expect(find.text('hello'), findsOneWidget);
    });
  });
}
