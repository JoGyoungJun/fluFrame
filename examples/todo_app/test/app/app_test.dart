import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/app/app.dart';
import 'package:todo_app/features/auth/presentation/login_screen.dart';
import 'package:todo_app/features/auth/presentation/profile_screen.dart';
import 'package:todo_app/features/home/presentation/home_screen.dart';
import 'package:todo_app/features/settings/presentation/settings_screen.dart';

import '../helpers/helpers.dart';

void main() {
  group('AppRoot', () {
    testWidgets('boots to the home screen with bottom navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appTestOverrides(),
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('switches to the settings tab', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appTestOverrides(),
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('profile tab redirects to login while signed out', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appTestOverrides(),
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('signing in lands on profile; signing out returns to login', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appTestOverrides(),
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'dev@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'secret1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Signed in as dev@example.com'), findsOneWidget);

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });
}
