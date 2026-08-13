import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/widgets/async_value_widget.dart';
import 'package:todo_app/core/widgets/content_width.dart';
import 'package:todo_app/features/todos/domain/todo.dart';
import 'package:todo_app/features/todos/presentation/todos_controller.dart';
import 'package:todo_app/l10n/gen/app_localizations.dart';

/// Persisted todo list: add, toggle, delete.
class TodosScreen extends ConsumerStatefulWidget {
  /// Creates the todos screen.
  const TodosScreen({super.key});

  @override
  ConsumerState<TodosScreen> createState() => _TodosScreenState();
}

class _TodosScreenState extends ConsumerState<TodosScreen> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    unawaited(ref.read(todosControllerProvider.notifier).add(_input.text));
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todos = ref.watch(todosControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.todosTitle)),
      body: ContentWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _input,
                decoration: InputDecoration(
                  hintText: l10n.addTodoHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _submit,
                    icon: const Icon(Icons.add),
                    tooltip: l10n.addTodoTooltip,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            Expanded(
              child: AsyncValueWidget<List<Todo>>(
                value: todos,
                onRetry: () => ref.invalidate(todosControllerProvider),
                data: (items) => items.isEmpty
                    ? Center(child: Text(l10n.emptyTodos))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final todo = items[index];
                          return CheckboxListTile(
                            value: todo.done,
                            onChanged: (_) => unawaited(
                              ref
                                  .read(todosControllerProvider.notifier)
                                  .toggle(todo.id),
                            ),
                            title: Text(
                              todo.title,
                              style: todo.done
                                  ? const TextStyle(
                                      decoration: TextDecoration.lineThrough,
                                    )
                                  : null,
                            ),
                            secondary: IconButton(
                              onPressed: () => unawaited(
                                ref
                                    .read(todosControllerProvider.notifier)
                                    .remove(todo.id),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.deleteTodoTooltip,
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
