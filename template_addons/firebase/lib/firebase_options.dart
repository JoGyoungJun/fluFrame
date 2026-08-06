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
/// Until then this getter throws. `main.dart` catches it, reports it
/// through the app's error seam, and starts anyway on the in-memory auth
/// fake — a loud, honest reminder that still leaves you an app to look
/// at, instead of the black screen an uncaught throw before `runApp`
/// produces.
class DefaultFirebaseOptions {
  /// Options for the current platform.
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured yet. Run: flutterfire configure '
    '(see https://firebase.google.com/docs/flutter/setup)',
  );
}
