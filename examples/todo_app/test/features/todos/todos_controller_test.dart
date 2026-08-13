import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/todos/presentation/todos_controller.dart';

import '../../helpers/helpers.dart';

void main() {
  group('TodosController', () {
    test('starts empty and add persists', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );

      expect(await container.read(todosControllerProvider.future), isEmpty);

      await container.read(todosControllerProvider.notifier).add('Buy milk');

      final todos = await container.read(todosControllerProvider.future);
      expect(todos, hasLength(1));
      expect(todos.single.title, 'Buy milk');
      expect(await store.getString('todos.items'), contains('Buy milk'));
    });

    test('blank titles are ignored', () async {
      final container = createContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );

      await container.read(todosControllerProvider.notifier).add('   ');

      expect(await container.read(todosControllerProvider.future), isEmpty);
    });

    test('toggle flips done and persists', () async {
      final store = InMemoryKeyValueStore();
      final container = createContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await container.read(todosControllerProvider.notifier).add('Task');
      final id = (await container.read(
        todosControllerProvider.future,
      )).single.id;

      await container.read(todosControllerProvider.notifier).toggle(id);

      final todos = await container.read(todosControllerProvider.future);
      expect(todos.single.done, isTrue);
      expect(await store.getString('todos.items'), contains('"done":true'));
    });

    test('remove deletes the todo', () async {
      final container = createContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      await container.read(todosControllerProvider.notifier).add('Task');
      final id = (await container.read(
        todosControllerProvider.future,
      )).single.id;

      await container.read(todosControllerProvider.notifier).remove(id);

      expect(await container.read(todosControllerProvider.future), isEmpty);
    });
  });
}
