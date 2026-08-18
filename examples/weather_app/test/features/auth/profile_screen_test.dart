import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/storage/key_value_store.dart';
import 'package:weather_app/features/auth/domain/user.dart';
import 'package:weather_app/features/auth/presentation/auth_controller.dart';
import 'package:weather_app/features/auth/presentation/profile_screen.dart';

import '../../helpers/helpers.dart';

/// Stands in for the router's auth redirect.
///
/// Signing out clears the session whether or not the repository manages
/// to, so this screen is replaced either way — which is why the failure
/// message goes to the app-level ScaffoldMessenger rather than into the
/// screen. Pumping ProfileScreen alone would prove nothing: it is gone
/// by the time the message needs reading.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(authControllerProvider) == null) {
      return const Scaffold(body: Center(child: Text('signed out')));
    }
    return const ProfileScreen();
  }
}

void main() {
  group('ProfileScreen', () {
    testWidgets('a failed sign-out is reported to the user', (tester) async {
      // Regression: the button fired signOut through unawaited(), so a
      // store that refused the delete threw into the zone — where
      // onPlatformError logs it and a release build shows the user
      // nothing. The button read as dead.
      await tester.pumpApp(
        const _AuthGate(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            FailingKeyValueStore(failRemovals: true),
          ),
          initialUserProvider.overrideWithValue(
            const User(email: 'dev@example.com'),
          ),
        ],
      );

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Something went wrong.'), findsOneWidget);
      // And the session cleared anyway, so the app is not left behind a
      // sign-out that cannot complete.
      expect(find.text('signed out'), findsOneWidget);

      // Drain the snackbar's display timer: one still pending at
      // teardown fails the test (see the #158 note in helpers.dart).
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('a sign-out that works reports nothing', (tester) async {
      await tester.pumpApp(
        const _AuthGate(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          initialUserProvider.overrideWithValue(
            const User(email: 'dev@example.com'),
          ),
        ],
      );

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('signed out'), findsOneWidget);
      expect(find.text('Something went wrong.'), findsNothing);
    });
  });
}
