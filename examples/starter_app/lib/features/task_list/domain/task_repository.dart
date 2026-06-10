import 'package:fulframe_core/fulframe_core.dart';

import 'task_item.dart';

abstract interface class TaskRepository {
  Future<Result<AppException, List<TaskItem>>> loadTasks();

  Future<Result<AppException, TaskItem>> addTask(String title);
}
