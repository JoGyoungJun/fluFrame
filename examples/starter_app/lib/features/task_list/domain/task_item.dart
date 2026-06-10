final class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    this.isComplete = false,
  });

  final String id;
  final String title;
  final bool isComplete;

  TaskItem complete() {
    return TaskItem(
      id: id,
      title: title,
      isComplete: true,
    );
  }
}
