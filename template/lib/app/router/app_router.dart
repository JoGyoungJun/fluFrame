import 'package:fluframe_app/features/home/presentation/home_screen.dart';
import 'package:fluframe_app/features/posts/presentation/post_detail_screen.dart';
import 'package:fluframe_app/features/posts/presentation/post_not_found_screen.dart';
import 'package:fluframe_app/features/posts/presentation/posts_screen.dart';
import 'package:fluframe_app/features/settings/presentation/settings_screen.dart';
import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Provider for the app-wide [GoRouter].
///
/// Route map:
/// - `/home` — landing screen (tab 1)
///   - `/home/posts` — sample post list
///   - `/home/posts/:id` — post detail
/// - `/settings` — preferences (tab 2)
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
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
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
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
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTab,
          ),
        ],
      ),
    );
  }
}
