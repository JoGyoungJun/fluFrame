import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/auth/domain/auth_exception.dart';
import 'package:todo_app/features/auth/domain/user.dart';
import 'package:todo_app/features/auth/presentation/auth_controller.dart';

import '../../helpers/helpers.dart';

void main() {
  group('AuthController', () {
    test('starts from the initial override', () {
      final container = createContainer(
        overrides: [
          initialUserProvider.overrideWithValue(
            const User(email: 'dev@example.com'),
          ),
        ],
      );

      expect(
        container.read(authControllerProvider),
        const User(email: 'dev@example.com'),
      );
    });

    test('signIn publishes the session and persists it', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'dev@example.com', password: 'secret1');

      expect(
        container.read(authControllerProvider),
        const User(email: 'dev@example.com'),
      );
      expect(await store.getString('auth.session.email'), 'dev@example.com');
    });

    test('failed signIn rethrows and leaves the state signed out', () async {
      final container = createContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .signIn(email: 'dev@example.com', password: 'nope'),
        throwsA(isA<AuthException>()),
      );
      expect(container.read(authControllerProvider), isNull);
    });

    test('signOut clears the state and the persisted session', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await container
          .read(authControllerProvider.notifier)
          .signIn(email: 'dev@example.com', password: 'secret1');

      await container.read(authControllerProvider.notifier).signOut();

      expect(container.read(authControllerProvider), isNull);
      expect(await store.getString('auth.session.email'), isNull);
    });
  });
}
