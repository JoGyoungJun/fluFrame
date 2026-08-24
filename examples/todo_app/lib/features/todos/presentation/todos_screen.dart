import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:todo_app/core/logging/app_logger.dart';
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

  TodosController get _todos => ref.read(todosControllerProvider.notifier);

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Adds what was typed, keeping the text when it could not be saved.
  Future<void> _submit() async {
    final saved = await _persist(() => _todos.add(_input.text));
    // Cleared on success only. The clear ran unconditionally beside an
    // `unawaited` add before, so a write the store refused ate the todo
    // *and* what the user had typed, and the field read as if it had
    // worked. `mounted` because _input is disposed with the screen.
    if (saved && mounted) _input.clear();
  }

  /// Runs [mutation], reporting a failure the user can actually see.
  ///
  /// Returns whether it got through.
  ///
  /// Each of these left through `unawaited` before, so a store that
  /// refused the write resolved to nothing: the error reached the zone,
  /// where `onPlatformError` logs it and a release build shows the user
  /// nothing at all.
  ///
  /// The messenger and the l10n object are resolved before the `await` on
  /// purpose — [BuildContext] must not be touched after the gap.
  Future<bool> _persist(Future<void> Function() mutation) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final logger = ref.read(appLoggerProvider);
    try {
      await mutation();
      return true;
    } on Object catch (error, stackTrace) {
      // Nothing here models a storage failure — `shared_preferences`
      // raises a PlatformException, web `localStorage` a quota Error — so
      // the generic message, with the cause kept in the log where the
      // underlying bug stays findable.
      logger.error('Saving the todo list failed', error, stackTrace);
      messenger.showSnackBar(SnackBar(content: Text(l10n.genericErrorMessage)));
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final todos = ref.watch(todosControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.todosTitle)),
      body: Column(
        children: [
          // Only the field is wrapped. ContentWidth's Align receives
          // pointer events inside its own box alone, so wrapping the whole
          // body left the outer 280px of a 1400px window dead to the mouse
          // wheel — the list below takes the same inset as padding.
          ContentWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _input,
                decoration: InputDecoration(
                  hintText: l10n.addTodoHint,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    // Awaited inside the callback rather than handed over
                    // as a tear-off, so the failure is part of the same
                    // sequence instead of a dropped Future.
                    onPressed: () async {
                      await _submit();
                    },
                    icon: const Icon(Icons.add),
                    tooltip: l10n.addTodoTooltip,
                  ),
                ),
                onSubmitted: (_) async {
                  await _submit();
                },
              ),
            ),
          ),
          Expanded(
            child: AsyncValueWidget<List<Todo>>(
              value: todos,
              onRetry: () => ref.invalidate(todosControllerProvider),
              data: (items) => items.isEmpty
                  ? Center(child: Text(l10n.emptyTodos))
                  : ListView.builder(
                      // Padding, not a ContentWidth wrapper: the list
                      // stays full-bleed so the mouse wheel keeps working
                      // over the gutters, and only the rows move. See
                      // ContentWidth.insetFor.
                      padding: EdgeInsets.symmetric(
                        horizontal: ContentWidth.insetFor(
                          MediaQuery.sizeOf(context).width,
                        ),
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final todo = items[index];
                        return CheckboxListTile(
                          value: todo.done,
                          onChanged: (_) async {
                            await _persist(() => _todos.toggle(todo.id));
                          },
                          title: Text(
                            todo.title,
                            style: todo.done
                                ? const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  )
                                : null,
                          ),
                          secondary: IconButton(
                            onPressed: () async {
                              await _persist(() => _todos.remove(todo.id));
                            },
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
    );
  }
}
