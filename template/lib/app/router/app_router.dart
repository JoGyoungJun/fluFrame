import 'package:fluframe_app/app/router/route_not_found_screen.dart';
import 'package:fluframe_app/core/analytics/analytics_service.dart';
import 'package:fluframe_app/features/auth/presentation/auth_controller.dart';
import 'package:fluframe_app/features/auth/presentation/login_screen.dart';
import 'package:fluframe_app/features/auth/presentation/profile_screen.dart';
import 'package:fluframe_app/features/home/presentation/home_screen.dart';
import 'package:fluframe_app/features/posts/presentation/post_detail_screen.dart';
import 'package:fluframe_app/features/posts/presentation/post_not_found_screen.dart';
import 'package:fluframe_app/features/posts/presentation/posts_screen.dart';
import 'package:fluframe_app/features/settings/presentation/settings_screen.dart';
import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Bridges auth-state changes into a [Listenable] so GoRouter re-runs its
/// redirect without the router itself being rebuilt (which would lose
/// navigation state).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (previous, next) => notifyListeners());
  }
}

/// Provider for the app-wide [GoRouter].
///
/// Route map:
/// - `/home` — landing screen (tab 1)
///   - `/home/posts` — sample post list
///   - `/home/posts/:id` — post detail
/// - `/profile` — signed-in profile (tab 2, auth-gated)
/// - `/settings` — preferences (tab 3)
/// - `/login` — full-screen sign-in (root navigator, above the shell)
/// - `/` — redirects to `/home`, so the app's own root URL resolves
/// - anything else — [RouteNotFoundScreen]
///
/// Gating: only `/profile` requires auth — the rest of the demo stays
/// explorable. To gate the whole app instead, drop the `startsWith`
/// check in the redirect below (see the backend guides).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _AuthRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);
  // read, not watch: watching would rebuild the whole router — losing the
  // navigation stack — every time the analytics provider is invalidated,
  // exactly the trap the comment above warns about for auth.
  final analytics = ref.read(analyticsServiceProvider);
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refreshNotifier,
    errorBuilder: (context, state) =>
        RouteNotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final signedIn = ref.read(authControllerProvider) != null;
      final location = state.matchedLocation;
      if (!signedIn && location.startsWith('/profile')) {
        return Uri(
          path: '/login',
          queryParameters: {'from': state.uri.toString()},
        ).toString();
      }
      if (signedIn && location == '/login') {
        return state.uri.queryParameters['from'] ?? '/home';
      }
      return null;
    },
    routes: [
      // The app lives under /home; `/` exists only so the root URL (and
      // anything that hard-codes it, including go_router's own default
      // error page) resolves instead of dead-ending.
      GoRoute(path: '/', redirect: (context, state) => '/home'),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppNavigationShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'posts',
                    builder: (context, state) => const PostsScreen(),
                    routes: [
                      GoRoute(
                        path: ':id',
                        builder: (context, state) {
                          final id = int.tryParse(
                            state.pathParameters['id'] ?? '',
                          );
                          if (id == null) return const PostNotFoundScreen();
                          return PostDetailScreen(postId: id);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  // Automatic screen tracking: the delegate fires on every navigation,
  // including shell-branch tab switches. Consecutive duplicates (e.g.
  // redirects settling) are collapsed.
  //
  // The route PATTERN is reported (`/home/posts/:id`), never the resolved
  // path (`/home/posts/42`). Concrete paths explode the cardinality of
  // every analytics dashboard, and the moment a route carries something
  // like `/invite/:token` they ship user secrets to a third party.
  var lastReportedPattern = '';
  void reportScreenView() {
    final pattern = router.routerDelegate.currentConfiguration.fullPath;
    if (pattern == lastReportedPattern) return;
    lastReportedPattern = pattern;
    analytics.logScreenView(pattern);
  }

  router.routerDelegate.addListener(reportScreenView);
  ref.onDispose(() => router.routerDelegate.removeListener(reportScreenView));
  return router;
});

/// Scaffold hosting the bottom navigation bar around the active branch.
class AppNavigationShell extends StatelessWidget {
  /// Creates the navigation shell.
  const AppNavigationShell({required this.navigationShell, super.key});

  /// The active branch container provided by [StatefulShellRoute].
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.profileTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTab,
          ),
        ],
      ),
    );
  }
}
