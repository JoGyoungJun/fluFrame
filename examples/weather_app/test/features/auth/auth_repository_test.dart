import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/features/auth/data/auth_repository.dart';
import 'package:weather_app/features/auth/domain/auth_exception.dart';
import 'package:weather_app/features/auth/domain/user.dart';

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
}
