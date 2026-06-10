import 'package:fulframe_core/fulframe_core.dart';

import '../domain/task_item.dart';
import '../domain/task_repository.dart';

final class InMemoryTaskRepository implements TaskRepository {
  final List<TaskItem> _items = <TaskItem>[];
  int _nextId = 1;

  @override
  Future<Result<AppException, List<TaskItem>>> loadTasks() async {
    return Result.success(List<TaskItem>.unmodifiable(_items));
  }

  @override
  Future<Result<AppException, TaskItem>> addTask(String title) async {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      return const Result.failure(
        AppException(
          'Task title is required.',
          code: 'empty_task_title',
        ),
      );
    }

    final task = TaskItem(
      id: 'task-${_nextId++}',
      title: normalizedTitle,
    );
    _items.add(task);
    return Result.success(task);
  }
}
