import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

/// Storage whose writes fail — the shape a real backend failure (socket
/// error, misconfigured SDK) takes by the time it reaches the form.
class _UnwritableKeyValueStore implements KeyValueStore {
  /// Number of accepted writes; a second concurrent submit would add one.
  int writes = 0;

  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async {
    writes++;
    throw StateError('storage unavailable');
  }

  @override
  Future<void> remove(String key) async {}
}

void main() {
  group('LoginScreen', () {
    testWidgets('shows required-field errors on empty submit', (tester) async {
      await tester.pumpApp(const LoginScreen());

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter your email.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('rejects a malformed email', (tester) async {
      await tester.pumpApp(const LoginScreen());

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.enterText(find.byType(TextFormField).last, 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows the failure message when credentials are rejected', (
      tester,
    ) async {
      await tester.pumpApp(
        const LoginScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'dev@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'nope');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sign-in failed. Check your credentials.'),
        findsOneWidget,
      );
    });

    testWidgets('shows the generic message when sign-in fails unexpectedly', (
      tester,
    ) async {
      // Regression: only AuthException was caught, so anything else a
      // real backend raises escaped into the zone — the form was left
      // with no message and the user with a button that did nothing.
      await tester.pumpApp(
        const LoginScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(_UnwritableKeyValueStore()),
        ],
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'dev@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
        reason: 'the form must be usable again after a failure',
      );
    });

    testWidgets('a submit while one is in flight does not sign in twice', (
      tester,
    ) async {
      // The disabled button is not the only entry point: the password
      // field submits on Enter, which is not gated by it.
      final store = _UnwritableKeyValueStore();
      await tester.pumpApp(
        const LoginScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await tester.enterText(
        find.byType(TextFormField).first,
        'dev@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret1');
      final password = tester.widget<TextField>(find.byType(TextField).last);
      password.onSubmitted!('secret1');
      password.onSubmitted!('secret1');
      await tester.pumpAndSettle();

      expect(store.writes, 1);
    });
  });
}
