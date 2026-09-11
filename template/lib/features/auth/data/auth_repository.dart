import 'package:fluframe_app/core/config/app_config.dart';
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Authenticates users and restores persisted sessions.
///
/// This interface is the single seam a real backend plugs into. The
/// Firebase and Supabase guides at
/// https://github.com/JoGyoungJun/fluFrame/tree/main/docs/guides show
/// the exact swap.
abstract interface class AuthRepository {
  /// Signs in with [email] and [password].
  ///
  /// Throws [AuthException] when the credentials are rejected.
  Future<User> signIn({required String email, required String password});

  /// Ends the current session, clearing anything persisted.
  ///
  /// Throws [AuthException] when the backend refuses the sign-out, so a
  /// caller never has to catch a backend SDK's own type to tell one
  /// failure from another — the same clause [signIn] carries.
  Future<void> signOut();

  /// Restores the persisted session, or `null` when nobody is signed in.
  Future<User?> restoreSession();
}

/// [AuthRepository] fake for the template: accepts any credentials whose
/// password has at least 6 characters and persists the session locally.
///
/// Swap it via [authRepositoryProvider] for a real backend.
class InMemoryAuthRepository implements AuthRepository {
  /// Creates a repository persisting the session in [store].
  InMemoryAuthRepository(KeyValueStore store) : _store = store;

  final KeyValueStore _store;

  static const String _sessionKey = 'auth.session.email';
  static const int _minPasswordLength = 6;

  /// Simulated network latency so loading states are visible in the UI.
  static const Duration latency = Duration(milliseconds: 400);

  @override
  Future<User> signIn({
    required String email,
    required String password,
  }) async {
    await Future<void>.delayed(latency);
    if (password.length < _minPasswordLength) {
      throw const AuthException('Invalid credentials.');
    }
    await _store.setString(_sessionKey, email);
    return User(email: email);
  }

  @override
  Future<void> signOut() => _store.remove(_sessionKey);

  @override
  Future<User?> restoreSession() async {
    final email = await _store.getString(_sessionKey);
    return email == null ? null : User(email: email);
  }
}

/// [AuthRepository] that refuses every sign-in because this build was
/// never given the backend it was generated against.
///
/// Named after what it is, not what it does: the app has a backend
/// selected and no configuration for it, and the only safe answer to a
/// credential is "no". [InMemoryAuthRepository] answers "yes" to any
/// six-character password, which is why it must never be what a release
/// falls back to — see [failClosedWhenUnconfigured].
class UnconfiguredAuthRepository implements AuthRepository {
  /// Creates a repository naming [backend] in every refusal.
  const UnconfiguredAuthRepository(this.backend);

  /// Display name of the backend that was selected but not configured.
  final String backend;

  /// The message every refused sign-in carries.
  ///
  /// Deliberately actionable: the failure is a build-configuration
  /// mistake, and the person who can fix it is the one who ran the build.
  String get message =>
      '$backend is not configured for this build — rebuild with '
      '--dart-define-from-file=env/prod.json once the backend keys are '
      'set.';

  @override
  Future<User> signIn({
    required String email,
    required String password,
  }) async => throw AuthException(message);

  /// No-op: [signIn] never succeeds, so there is no session to end.
  ///
  /// Throwing here instead would turn a sign-out button that has nothing
  /// to do into an error the user cannot act on.
  @override
  Future<void> signOut() async {}

  @override
  Future<User?> restoreSession() async => null;
}

/// The repository a `--backend` build must use while that backend has no
/// configuration.
///
/// Called by the `--backend` addon files (`template_addons/*/`), which is
/// why it lives here rather than beside them: this is the decision worth
/// testing, and only `template/lib` is covered by the suite.
///
/// [failClosed] defaults to [failClosedWhenUnconfigured]. Tests pass it
/// explicitly — both halves of that constant fold to `false` under
/// `flutter test`, so neither branch is otherwise reachable.
AuthRepository unconfiguredBackendRepository(
  String backend,
  KeyValueStore store, {
  bool failClosed = failClosedWhenUnconfigured,
}) => failClosed
    ? UnconfiguredAuthRepository(backend)
    : InMemoryAuthRepository(store);

/// Provider for the app-wide [AuthRepository] — the swap point for real
/// backends.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),
);
