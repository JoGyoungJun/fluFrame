import 'package:fluframe_app/app/app.dart';
import 'package:fluframe_app/app/router/route_not_found_screen.dart';
import 'package:fluframe_app/core/analytics/analytics_service.dart';
import 'package:fluframe_app/features/auth/presentation/login_screen.dart';
import 'package:fluframe_app/features/auth/presentation/profile_screen.dart';
import 'package:fluframe_app/features/home/presentation/home_screen.dart';
import 'package:fluframe_app/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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

    testWidgets('navigation reports screen views', (tester) async {
      final analytics = RecordingAnalyticsService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appTestOverrides(),
            analyticsServiceProvider.overrideWithValue(analytics),
          ],
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(analytics.screenViews, contains('/settings'));
    });

    testWidgets('screen views report the route pattern, not the path', (
      tester,
    ) async {
      // Regression: `/home/posts/42` was sent verbatim, which explodes
      // dashboard cardinality and would leak a value like /invite/:token
      // to a third-party service the moment such a route exists.
      final analytics = RecordingAnalyticsService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...appTestOverrides(),
            analyticsServiceProvider.overrideWithValue(analytics),
          ],
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      GoRouter.of(context).go('/home/posts/42');
      await tester.pumpAndSettle();

      expect(analytics.screenViews, contains('/home/posts/:id'));
      expect(analytics.screenViews, isNot(contains('/home/posts/42')));
    });

    testWidgets('an unmatched deep link offers a way back', (tester) async {
      // Regression: go_router's default error page was reached instead,
      // and its only button navigates to `/`, which this app did not
      // define — leaving force-quit as the sole escape.
      await tester.pumpWidget(
        ProviderScope(
          overrides: appTestOverrides(),
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      GoRouter.of(context).go('/nope/not/a/route');
      await tester.pumpAndSettle();

      expect(find.byType(RouteNotFoundScreen), findsOneWidget);

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('the root URL resolves to home', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: appTestOverrides(),
          child: const AppRoot(),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(HomeScreen));
      GoRouter.of(context).go('/settings');
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.byType(SettingsScreen))).go('/');
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(RouteNotFoundScreen), findsNothing);
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
