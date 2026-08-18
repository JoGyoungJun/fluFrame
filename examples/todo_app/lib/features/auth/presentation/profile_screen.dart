import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/logging/app_logger.dart';
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
              // Awaited inside the callback rather than handed over as a
              // tear-off, so the failure below is part of the same
              // sequence instead of a dropped Future.
              onPressed: () async {
                await _signOut(context, ref, l10n);
              },
              child: Text(l10n.signOutButton),
            ),
          ],
        ),
      ),
    );
  }

  /// Signs out, reporting a failure the user can actually see.
  ///
  /// This ran through `unawaited` before, so a repository that threw
  /// resolved to nothing: the error reached the zone, where
  /// `onPlatformError` logs it and a release build shows nothing, and the
  /// button read as dead.
  ///
  /// The messenger is resolved before the `await` on purpose. Signing out
  /// clears the session either way (see [AuthController.signOut]), so the
  /// router redirect takes this screen with it — the message has to
  /// belong to the app-level [ScaffoldMessenger] that outlives it, and
  /// [BuildContext] must not be touched after the gap.
  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final logger = ref.read(appLoggerProvider);
    try {
      await ref.read(authControllerProvider.notifier).signOut();
    } on Object catch (error, stackTrace) {
      // Nothing here models a sign-out failure, and a backend addon can
      // raise anything its SDK defines — so the generic message, with the
      // cause kept in the log where the underlying bug stays findable.
      logger.error('Sign-out failed', error, stackTrace);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.genericErrorMessage)),
      );
    }
  }
}
