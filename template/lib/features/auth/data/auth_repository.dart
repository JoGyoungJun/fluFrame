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

/// Provider for the app-wide [AuthRepository] — the swap point for real
/// backends.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),
);
