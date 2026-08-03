import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/todos/domain/todo.dart';

/// Persists the todo list as JSON in the [KeyValueStore].
class TodosRepository {
  /// Creates a repository backed by [store].
  TodosRepository(KeyValueStore store) : _store = store;

  final KeyValueStore _store;

  static const String _key = 'todos.items';

  /// Loads all todos (empty when nothing has been saved yet).
  Future<List<Todo>> load() async {
    final raw = await _store.getString(_key);
    if (raw == null) return const [];
    final list = jsonDecode(raw) as List<dynamic>;
    return [
      for (final json in list) Todo.fromJson(json as Map<String, Object?>),
    ];
  }

  /// Persists [todos], replacing the previous list.
  Future<void> save(List<Todo> todos) => _store.setString(
    _key,
    jsonEncode([for (final todo in todos) todo.toJson()]),
  );
}

/// Provider for the app-wide [TodosRepository].
final todosRepositoryProvider = Provider<TodosRepository>(
  (ref) => TodosRepository(ref.watch(keyValueStoreProvider)),
);
