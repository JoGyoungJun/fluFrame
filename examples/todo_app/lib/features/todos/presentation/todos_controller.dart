import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/features/todos/data/todos_repository.dart';
import 'package:todo_app/features/todos/domain/todo.dart';

/// Loads and mutates the todo list; every change persists immediately.
class TodosController extends AsyncNotifier<List<Todo>> {
  @override
  Future<List<Todo>> build() => ref.watch(todosRepositoryProvider).load();

  Future<void> _apply(List<Todo> todos) async {
    state = AsyncData(todos);
    await ref.read(todosRepositoryProvider).save(todos);
  }

  /// Adds a todo titled [title]; blank titles are ignored.
  Future<void> add(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    final current = await future;
    final todo = Todo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: trimmed,
    );
    await _apply([...current, todo]);
  }

  /// Flips the done state of the todo with [id].
  Future<void> toggle(String id) async {
    final current = await future;
    await _apply([
      for (final todo in current)
        if (todo.id == id) todo.copyWith(done: !todo.done) else todo,
    ]);
  }

  /// Removes the todo with [id].
  Future<void> remove(String id) async {
    final current = await future;
    await _apply([
      for (final todo in current)
        if (todo.id != id) todo,
    ]);
  }
}

/// Provider for the [TodosController].
final todosControllerProvider =
    AsyncNotifierProvider<TodosController, List<Todo>>(TodosController.new);
