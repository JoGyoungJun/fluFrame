import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/features/auth/presentation/auth_controller.dart';
import 'package:todo_app/l10n/gen/app_localizations.dart';

/// Signed-in user's profile with a sign-out action.
///
/// This tab is auth-gated by the router; signing out flips the auth state
/// and the redirect immediately sends the user back to `/login`.
class ProfileScreen extends ConsumerWidget {
  /// Creates the profile screen.
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider);
    if (user == null) {
      // Redirecting to /login — render nothing for the frame in between.
      return const SizedBox.shrink();
    }
    final initial = user.email.isEmpty ? '?' : user.email[0].toUpperCase();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              child: Text(
                initial,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.profileSignedInAs(user.email),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => unawaited(
                ref.read(authControllerProvider.notifier).signOut(),
              ),
              child: Text(l10n.signOutButton),
            ),
          ],
        ),
      ),
    );
  }
}
