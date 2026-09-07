import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/config/app_config.dart';
import 'package:todo_app/features/auth/data/auth_repository.dart';
import 'package:todo_app/features/auth/domain/auth_exception.dart';
import 'package:todo_app/features/auth/domain/user.dart';

import '../../helpers/helpers.dart';

void main() {
  group('InMemoryAuthRepository', () {
    late InMemoryKeyValueStore store;
    late InMemoryAuthRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = InMemoryAuthRepository(store);
    });

    test('signIn persists the session and returns the user', () async {
      final user = await repository.signIn(
        email: 'dev@example.com',
        password: 'secret1',
      );

      expect(user, const User(email: 'dev@example.com'));
      expect(await store.getString('auth.session.email'), 'dev@example.com');
    });

    test('signIn rejects short passwords without persisting', () async {
      await expectLater(
        repository.signIn(email: 'dev@example.com', password: 'short'),
        throwsA(isA<AuthException>()),
      );
      expect(await store.getString('auth.session.email'), isNull);
    });

    test('restoreSession returns null when nobody signed in', () async {
      expect(await repository.restoreSession(), isNull);
    });

    test('restoreSession returns the persisted user', () async {
      await repository.signIn(email: 'dev@example.com', password: 'secret1');

      expect(
        await repository.restoreSession(),
        const User(email: 'dev@example.com'),
      );
    });

    test('signOut clears the persisted session', () async {
      await repository.signIn(email: 'dev@example.com', password: 'secret1');
      await repository.signOut();

      expect(await repository.restoreSession(), isNull);
    });
  });

  group('UnconfiguredAuthRepository', () {
    const repository = UnconfiguredAuthRepository('Supabase');

    test('refuses any sign-in, naming the backend and the fix', () async {
      await expectLater(
        repository.signIn(email: 'dev@example.com', password: 'secret1'),
        throwsA(
          isA<AuthException>()
              .having((error) => error.message, 'message', contains('Supabase'))
              .having(
                (error) => error.message,
                'message',
                contains('--dart-define-from-file'),
              ),
        ),
      );
    });

    test('refuses the credentials the in-memory fake accepts', () async {
      // The exact pair InMemoryAuthRepository signs in: any email, any
      // six-character password. That is the hole this class closes.
      await expectLater(
        repository.signIn(email: 'attacker@example.com', password: '123456'),
        throwsA(isA<AuthException>()),
      );
    });

    test('restores nothing', () async {
      expect(await repository.restoreSession(), isNull);
    });

    test('signOut is a no-op rather than an error', () async {
      await expectLater(repository.signOut(), completes);
    });
  });

  group('unconfiguredBackendRepository', () {
    // Regression: the `--backend` addons returned InMemoryAuthRepository
    // for an unconfigured backend unconditionally, so a release built
    // without --dart-define-from-file shipped a login screen that accepted
    // any email with a six-character password, silently. Both branches are
    // pinned here because failClosedWhenUnconfigured folds to a constant
    // false under `flutter test` — an inverted guard would otherwise stay
    // green.
    test('fails closed when the build must not fall back', () {
      final repository = unconfiguredBackendRepository(
        'Firebase',
        InMemoryKeyValueStore(),
        failClosed: true,
      );

      expect(repository, isA<UnconfiguredAuthRepository>());
      expect(
        (repository as UnconfiguredAuthRepository).backend,
        'Firebase',
      );
    });

    test('keeps the dev fake when falling back is allowed', () {
      // failClosedWhenUnconfigured is `kReleaseMode || isProdFlavor`, and
      // the suite runs a debug `dev` build — so the default is the
      // falling-back branch, and passing it explicitly would only trip
      // avoid_redundant_argument_values. Asserting the constant first is
      // what makes the call below mean what it says.
      expect(failClosedWhenUnconfigured, isFalse);
      expect(
        unconfiguredBackendRepository('Firebase', InMemoryKeyValueStore()),
        isA<InMemoryAuthRepository>(),
      );
    });
  });
}
