import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// [AuthRepository] backed by Supabase Auth.
///
/// Configuration comes from `--dart-define-from-file` (see `env/*.json`:
/// SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY) via `Supabase.initialize` in
/// `main.dart`.
class SupabaseAuthRepository implements AuthRepository {
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
  Future<void> signOut() => _client.auth.signOut();

  @override
  Future<User?> restoreSession() async {
    final email = _client.auth.currentSession?.user.email;
    return email == null ? null : User(email: email);
  }
}
