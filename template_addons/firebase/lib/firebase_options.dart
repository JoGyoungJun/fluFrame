import 'package:firebase_core/firebase_core.dart';

/// Placeholder Firebase configuration so the generated app compiles
/// before `flutterfire configure` has run.
///
/// Replace this file by running:
///
/// ```sh
/// dart pub global activate flutterfire_cli
/// flutterfire configure
/// ```
///
/// Until then the app throws this error at startup on purpose — a loud,
/// honest reminder instead of a silently broken Firebase connection.
class DefaultFirebaseOptions {
  /// Options for the current platform.
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured yet. Run: flutterfire configure '
    '(see https://firebase.google.com/docs/flutter/setup)',
  );
}
