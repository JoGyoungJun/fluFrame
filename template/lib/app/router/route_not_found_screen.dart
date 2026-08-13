import 'package:fluframe_app/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Shown for any URL the router cannot match.
///
/// Without it go_router falls back to its built-in error page, whose only
/// button navigates to `/` — a location this app does not define. An
/// unmatched deep link was therefore a dead end nothing but force-quitting
/// escaped.
class RouteNotFoundScreen extends StatelessWidget {
  /// Creates the not-found screen for [location].
  const RouteNotFoundScreen({required this.location, super.key});

  /// The URL that matched no route.
  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeNotFoundTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.routeNotFoundMessage(location),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/home'),
                child: Text(l10n.routeNotFoundAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
