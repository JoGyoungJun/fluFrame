import 'dart:io';

import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/data/supabase_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/helpers.dart';

// Ships with the `--backend supabase` addon and runs inside the generated
// app, the only place supabase_flutter resolves. Everything here stays
// offline: nothing touches `Supabase.instance`, which throws until
// `main.dart` has run `Supabase.initialize`.
void main() {
  group('supabaseAuthOrFallback', () {
    test('reports an unconfigured build when SUPABASE_URL is unset', () {
      expect(
        SupabaseAuthRepository.isConfigured,
        isFalse,
        reason:
            'the suite runs without --dart-define-from-file, and the '
            'committed env/*.json ship SUPABASE_URL empty',
      );
    });

    test('the key gate requires BOTH keys, not just the URL', () {
      // The addon seeds SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY empty in
      // both env files, so a half-filled env/dev.local.json is the likely
      // first state. Gating on the URL alone flipped `isConfigured` true,
      // bypassed UnconfiguredAuthRepository and its release-mode refusal,
      // and produced a client that 401s on every request rather than an
      // app that says it is not configured.
      expect(supabaseKeysPresent, isFalse);
    });

    test('initialize failing leaves the build unconfigured', () {
      // Firebase reads `Firebase.apps.isNotEmpty`, which is false when
      // initializeApp threw. supabase_flutter has no equivalent probe, so
      // main.dart records the outcome here. Without it, a configured
      // build whose initialize failed (a typo'd URL — past the key gate)
      // still looked configured, got the real repository, and threw
      // "not initialized" on every auth call.
      expect(
        supabaseInitialized,
        isFalse,
        reason: 'main.dart has not run in a widget test',
      );
      expect(
        SupabaseAuthRepository.isConfigured,
        isFalse,
        reason: 'isConfigured must require the initialize to have succeeded',
      );
    });

    test('returns the in-memory fake while unconfigured', () async {
      final store = InMemoryKeyValueStore();

      final repository = supabaseAuthOrFallback(store);

      // A freshly generated app has no Supabase project yet. Handing it
      // the real repository leaves a login screen that throws on first
      // use, and `Supabase.initialize` with an empty URL throws before the
      // first frame — a black screen with nothing on it.
      expect(repository, isA<InMemoryAuthRepository>());
      // Type alone is not the contract: the app has to keep working.
      await repository.signIn(email: 'dev@example.com', password: 'secret1');
      expect(await repository.restoreSession(), isNotNull);
    });
  });

  group('SupabaseAuthRepository', () {
    // Read from the source rather than exercised: `_client` reaches
    // `Supabase.instance`, which throws until main.dart has initialized
    // it, and this suite stays offline on purpose (see the note above).
    //
    // signOut shipped as a bare `=> _client.auth.signOut()` while signIn
    // mapped its exception. profile_screen catches `on Object`, so the
    // user still got a message — what leaked was the contract: a
    // supabase.AuthException crossing the seam auth_exception.dart says
    // it never crosses, leaving no caller able to tell one sign-out
    // failure from another.
    test('signOut maps the SDK exception the way signIn does', () {
      const path = 'lib/features/auth/data/supabase_auth_repository.dart';
      final members = File(path).readAsStringSync().split('@override');
      final signOut = members.firstWhere(
        (member) => member.contains('Future<void> signOut()'),
        orElse: () => throw StateError('$path declares no signOut'),
      );

      expect(
        signOut,
        contains('on supabase.AuthException'),
        reason:
            'signOut must map the SDK exception onto AuthException, the '
            'type AuthRepository.signOut documents',
      );
      expect(signOut, contains('throw AuthException('));
    });
  });
}
