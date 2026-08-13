import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/data/firebase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/helpers.dart';

// Ships with the `--backend firebase` addon and runs inside the generated
// app, the only place firebase_core resolves. `Firebase.apps` reads a
// local map, so this needs no emulator, no network and no
// google-services.json.
void main() {
  group('firebaseAuthOrFallback', () {
    test('reports an unconfigured build when no app was initialized', () {
      // `lib/firebase_options.dart` throws until `flutterfire configure`
      // has run, so `main.dart` reports that failure and carries on with
      // no initialized app — exactly this state.
      expect(FirebaseAuthRepository.isConfigured, isFalse);
    });

    test('returns the in-memory fake while unconfigured', () async {
      final store = InMemoryKeyValueStore();

      final repository = firebaseAuthOrFallback(store);

      // Falling through to the real repository leaves a login screen that
      // throws ("No Firebase App '[DEFAULT]' has been created") the moment
      // anyone signs in — the first run of every generated app.
      expect(repository, isA<InMemoryAuthRepository>());
      // Type alone is not the contract: the app has to keep working.
      await repository.signIn(email: 'dev@example.com', password: 'secret1');
      expect(await repository.restoreSession(), isNotNull);
    });
  });
}
