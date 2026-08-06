import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';

/// The auth backend this build should use.
///
/// `lib/firebase_options.dart` throws until `flutterfire configure` has
/// run, so `Firebase.initializeApp` fails on a freshly generated app.
/// `main.dart` reports that failure and keeps going; this keeps the app
/// usable on the in-memory fake instead of leaving a login screen that
/// crashes the moment it is used.
AuthRepository firebaseAuthOrFallback(KeyValueStore store) =>
    FirebaseAuthRepository.isConfigured
    ? FirebaseAuthRepository()
    : InMemoryAuthRepository(store);

/// [AuthRepository] backed by Firebase Auth.
///
/// Requires `flutterfire configure` to have replaced
/// `lib/firebase_options.dart` (see the post-create notes).
class FirebaseAuthRepository implements AuthRepository {
  /// Whether `Firebase.initializeApp` succeeded during boot.
  static bool get isConfigured => firebase_core.Firebase.apps.isNotEmpty;

  firebase.FirebaseAuth get _auth => firebase.FirebaseAuth.instance;

  @override
  Future<User> signIn({required String email, required String password}) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final signedInEmail = credential.user?.email;
      if (signedInEmail == null) {
        throw const AuthException('Sign-in returned no user.');
      }
      return User(email: signedInEmail);
    } on firebase.FirebaseAuthException catch (error) {
      // Map the SDK's exception onto the app's type so the UI never
      // depends on Firebase.
      throw AuthException(error.message ?? error.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<User?> restoreSession() async {
    final email = _auth.currentUser?.email;
    return email == null ? null : User(email: email);
  }
}
