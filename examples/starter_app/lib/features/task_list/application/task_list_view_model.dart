import 'package:flutter/foundation.dart';
import 'package:fulframe_core/fulframe_core.dart';

import '../domain/task_item.dart';
import '../domain/task_repository.dart';

final class TaskListViewModel extends ChangeNotifier {
  TaskListViewModel({
    required TaskRepository repository,
    AppLogger logger = const NoopLogger(),
  })  : _repository = repository,
        _logger = logger;

  final TaskRepository _repository;
  final AppLogger _logger;

  bool _isLoading = false;
  AppException? _error;
  List<TaskItem> _tasks = <TaskItem>[];

  bool get isLoading => _isLoading;

  AppException? get error => _error;

  List<TaskItem> get tasks => List<TaskItem>.unmodifiable(_tasks);

  bool get isEmpty => !_isLoading && _error == null && _tasks.isEmpty;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _repository.loadTasks();
    result.fold(
      (failure) {
        _logger.error('Failed to load tasks.', error: failure);
        _error = failure;
        _tasks = <TaskItem>[];
      },
      (tasks) {
        _tasks = tasks;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addTask(String title) async {
    final result = await _repository.addTask(title);
    result.fold(
      (failure) {
        _logger.warning('Failed to add task.', error: failure);
        _error = failure;
      },
      (task) {
        _error = null;
        _tasks = [..._tasks, task];
      },
    );
    notifyListeners();
  }
}
