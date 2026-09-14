import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Whether this build was compiled with both Supabase keys.
///
/// Compile-time, so `main.dart` can decide whether to attempt
/// `Supabase.initialize` at all — which is why this is separate from
/// [SupabaseAuthRepository.isConfigured], the runtime answer that also
/// requires the initialize to have succeeded.
const bool supabaseKeysPresent =
    String.fromEnvironment('SUPABASE_URL') != '' &&
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY') != '';

/// Set by `main.dart` once `Supabase.initialize` returns without throwing.
///
/// Stands in for the `Firebase.apps.isNotEmpty` probe the Firebase addon
/// gets from its SDK; supabase_flutter has no readable equivalent.
bool supabaseInitialized = false;

/// The auth backend this build should use.
///
/// A freshly generated app has no Supabase project yet, and
/// `Supabase.initialize` with an empty URL throws before the first frame
/// — a black screen with nothing on it. Until both keys are set the app
/// keeps running on the in-memory fake, the same way the Sentry and
/// Amplitude addons stay inert without their keys.
///
/// That convenience is scoped to debug and profile builds of the `dev`
/// flavor. A release — or any `prod` build — that never received them
/// gets [UnconfiguredAuthRepository] instead: the fake signs in any email
/// with a six-character password, and shipping that as the login screen
/// is worse than shipping one that refuses everybody.
/// See `failClosedWhenUnconfigured` in `core/config/app_config.dart`.
AuthRepository supabaseAuthOrFallback(KeyValueStore store) =>
    SupabaseAuthRepository.isConfigured
    ? SupabaseAuthRepository()
    : unconfiguredBackendRepository('Supabase', store);

/// [AuthRepository] backed by Supabase Auth.
///
/// Configuration comes from `--dart-define-from-file` (see `env/*.json`:
/// SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY) via `Supabase.initialize` in
/// `main.dart`.
class SupabaseAuthRepository implements AuthRepository {
  /// Whether this build reached a Supabase project: it was given both
  /// keys, and `Supabase.initialize` then succeeded.
  ///
  /// Both halves are load-bearing, and neither is enough alone.
  ///
  /// Firebase gets the second half for free — `Firebase.apps.isNotEmpty`
  /// is false when `initializeApp` threw, so its fallback is correct
  /// without any extra state. Supabase exposes no equivalent probe:
  /// `Supabase.instance` throws rather than reporting, so a build whose
  /// `initialize` failed would otherwise still look configured here, be
  /// handed the real repository, and throw "not initialized" on every
  /// single auth call. [supabaseInitialized] closes that gap.
  ///
  /// The first half reads BOTH keys because the addon seeds both empty in
  /// `env/*.json`. Gating on the URL alone meant a half-filled env file
  /// flipped this to true, bypassed [unconfiguredBackendRepository] and
  /// its release-mode refusal, and produced a client that 401s on every
  /// request instead of an app that says it is not configured.
  static bool get isConfigured => supabaseKeysPresent && supabaseInitialized;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  Future<User> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final signedInEmail = response.user?.email;
      if (signedInEmail == null) {
        throw const AuthException('Sign-in returned no user.');
      }
      return User(email: signedInEmail);
    } on supabase.AuthException catch (error) {
      // Map the SDK's exception onto the app's type so the UI never
      // depends on Supabase.
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supabase.AuthException catch (error) {
      // Mapped exactly as signIn maps it: AuthRepository.signOut
      // documents AuthException, and a bare `=> _client.auth.signOut()`
      // let the SDK's own type straight past that seam.
      throw AuthException(error.message);
    }
  }

  @override
  Future<User?> restoreSession() async {
    final email = _client.auth.currentSession?.user.email;
    return email == null ? null : User(email: email);
  }
}
