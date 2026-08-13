import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:weather_app/features/auth/data/auth_repository.dart';
import 'package:weather_app/features/auth/domain/user.dart';

/// Session resolved from storage before `runApp` (see `main.dart`).
///
/// Overridden in the root `ProviderScope` so the first frame already
/// knows whether someone is signed in — no login flash on startup. It is
/// a boot *snapshot*: read once, and never consulted again.
final initialUserProvider = Provider<User?>((ref) => null);

/// The live session, held outside [AuthController] so it survives a
/// rebuild of the controller itself.
class _Session {
  _Session(this.user);

  User? user;
}

/// A `Notifier` is thrown away and re-created by `ref.invalidate` (and by
/// hot reload), and its `build` has to produce a state synchronously —
/// so whatever `build` reads is the state the app returns to. Reading
/// [initialUserProvider] there made the boot snapshot that answer
/// forever: every invalidation signed a signed-out user back in. This box
/// is rewritten on each sign-in and sign-out, so a rebuilt controller
/// resumes from where the app actually is.
final _sessionProvider = Provider<_Session>(
  // `read`, not `watch`: the snapshot is consumed once at startup and a
  // later change to it must not overwrite a live session.
  (ref) => _Session(ref.read(initialUserProvider)),
);

/// Holds the signed-in [User] (or `null`) and drives sign-in/out.
class AuthController extends Notifier<User?> {
  @override
  User? build() => ref.read(_sessionProvider).user;

  /// Signs in and publishes the new session.
  ///
  /// Rethrows the repository's AuthException so forms can render the
  /// failure message.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    _publish(
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password),
    );
  }

  /// Signs out and clears the session.
  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    _publish(null);
  }

  void _publish(User? user) {
    ref.read(_sessionProvider).user = user;
    state = user;
  }
}

/// Provider for the app-wide [AuthController].
final authControllerProvider = NotifierProvider<AuthController, User?>(
  AuthController.new,
);
