import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/todos/data/todos_repository.dart';
import 'package:todo_app/features/todos/domain/todo.dart';

import '../../helpers/helpers.dart';

void main() {
  group('TodosRepository', () {
    late InMemoryKeyValueStore store;
    late TodosRepository repository;

    setUp(() {
      store = InMemoryKeyValueStore();
      repository = TodosRepository(store);
    });

    test('nothing saved yet loads as empty', () async {
      expect(await repository.load(), isEmpty);
    });

    test('a saved list round-trips', () async {
      await repository.save(const [Todo(id: '1', title: 'Task')]);

      expect(await repository.load(), const [Todo(id: '1', title: 'Task')]);
    });

    test('save writes the versioned envelope', () async {
      await repository.save(const [Todo(id: '1', title: 'Task')]);

      expect(await store.getString('todos.items'), startsWith('{"version":1'));
    });

    test('a blob this build cannot read loads as empty', () async {
      // Regression: two bare casts stood here — `jsonDecode(raw) as List`
      // and `json as Map` — and Todo.fromJson on the wrong shape raises a
      // TypeError, an Error rather than an Exception. It reached the
      // screen as an AsyncError that no mutation could get past, because
      // each one opens with `await future` and that rethrows: save never
      // ran, so the blob could not be replaced from inside the app.
      await store.setString('todos.items', '{"not":"a list"}');

      expect(await repository.load(), isEmpty);
    });

    test('a truncated write loads as empty', () async {
      await store.setString('todos.items', '[{"id":"1","tit');

      expect(await repository.load(), isEmpty);
    });

    test('a newer schema version loads as empty', () async {
      await store.setString(
        'todos.items',
        '{"version":99,"todos":[{"id":"1","title":"Task","done":false}]}',
      );

      expect(await repository.load(), isEmpty);
    });

    test('a todo of the wrong shape loads as empty', () async {
      await store.setString('todos.items', '{"version":1,"todos":["nope"]}');

      expect(await repository.load(), isEmpty);
    });

    test('an unreadable blob is replaced by the next save', () async {
      // The half of the fix that breaks the deadlock: reading it as empty
      // is only useful because the write that follows can land.
      await store.setString('todos.items', '{"not":"a list"}');
      await repository.load();

      await repository.save(const [Todo(id: '1', title: 'Task')]);

      expect(await repository.load(), const [Todo(id: '1', title: 'Task')]);
    });

    test('a bare list from an older release still loads', () async {
      // What every already-installed copy has on disk. Migrating it
      // rather than discarding it is the difference between an upgrade
      // that keeps the user's todos and one that silently deletes them.
      await store.setString(
        'todos.items',
        jsonEncode([const Todo(id: '1', title: 'Task').toJson()]),
      );

      expect(await repository.load(), const [Todo(id: '1', title: 'Task')]);
    });
  });
}
