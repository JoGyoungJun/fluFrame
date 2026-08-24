import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/logging/app_logger.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/todos/domain/todo.dart';

/// Persists the todo list as JSON in the [KeyValueStore].
class TodosRepository {
  /// Creates a repository backed by [store].
  TodosRepository(KeyValueStore store) : _store = store;

  final KeyValueStore _store;

  static const String _key = 'todos.items';

  static const AppLogger _logger = AppLogger('todo_app.todos');

  /// Schema version of the stored blob.
  ///
  /// Bump this whenever [Todo]'s JSON shape changes. A blob whose version
  /// this build does not recognise is reported as empty rather than
  /// parsed, so a shape change costs the todos of an already-installed app
  /// instead of locking it out of its own screen.
  static const int _schema = 1;

  /// Loads all todos (empty when nothing readable has been saved yet).
  ///
  /// A blob this build cannot read is answered as an empty list, never as
  /// a throw. `TodosController.build` turns a throw into an `AsyncError`,
  /// and every mutation opens with `await future`, which rethrows it — so
  /// [save] could never run and nothing could replace the bad blob, while
  /// the screen's retry button re-ran the identical parse. The only exit
  /// was clearing the app's data.
  Future<List<Todo>> load() async {
    final raw = await _store.getString(_key);
    if (raw == null) return const [];
    final todos = _decode(raw);
    if (todos != null) return todos;
    // Left on disk, unlike the posts cache, which deletes what it cannot
    // read. That cache is disposable; this is the user's only copy, and a
    // rollback to the build that wrote it may still make sense of it.
    // Returning empty already unblocks the app: the next save replaces it.
    _logger.warning('Unreadable todo list ignored; starting from empty.');
    return const [];
  }

  /// Persists [todos] in the current envelope, replacing the previous list.
  Future<void> save(List<Todo> todos) => _store.setString(
    _key,
    jsonEncode({
      'version': _schema,
      'todos': [for (final todo in todos) todo.toJson()],
    }),
  );

  /// The stored todos, or `null` when [raw] is not a list this build reads.
  ///
  /// `on Object`, not `on Exception`: a truncated write reaches
  /// `jsonDecode` as a `FormatException`, but a payload of the wrong shape
  /// reaches `Todo.fromJson` as a `TypeError` — an `Error` rather than an
  /// `Exception`, which nothing between here and the widget tree catches.
  List<Todo>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      // Every release before the envelope wrote a bare JSON array, and
      // that is what sits on every installed device today. Migrated, not
      // discarded: discarding would silently delete real todos on upgrade.
      // The next save rewrites them wrapped.
      if (decoded is List) return _todosFrom(decoded);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['version'] != _schema) return null;
      final todos = decoded['todos'];
      if (todos is! List) return null;
      return _todosFrom(todos);
    } on Object {
      return null;
    }
  }

  List<Todo> _todosFrom(List<Object?> items) => [
    for (final json in items) Todo.fromJson(json as Map<String, Object?>),
  ];
}

/// Provider for the app-wide [TodosRepository].
final todosRepositoryProvider = Provider<TodosRepository>(
  (ref) => TodosRepository(ref.watch(keyValueStoreProvider)),
);
