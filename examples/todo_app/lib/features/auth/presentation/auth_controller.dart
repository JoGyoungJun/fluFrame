import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/features/auth/data/auth_repository.dart';
import 'package:todo_app/features/auth/domain/user.dart';

/// Session resolved from storage before `runApp` (see `main.dart`).
///
/// Overridden in the root `ProviderScope` so the first frame already
/// knows whether someone is signed in — no login flash on startup.
final initialUserProvider = Provider<User?>((ref) => null);

/// Holds the signed-in [User] (or `null`) and drives sign-in/out.
class AuthController extends Notifier<User?> {
  @override
  User? build() => ref.watch(initialUserProvider);

  /// Signs in and publishes the new session.
  ///
  /// Rethrows the repository's AuthException so forms can render the
  /// failure message.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = await ref
        .read(authRepositoryProvider)
        .signIn(email: email, password: password);
  }

  /// Signs out and clears the session.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = null;
  }
}

/// Provider for the app-wide [AuthController].
final authControllerProvider = NotifierProvider<AuthController, User?>(
  AuthController.new,
);
