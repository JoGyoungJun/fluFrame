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
}
