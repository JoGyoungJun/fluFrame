import 'package:flutter/material.dart';
import 'package:fulframe_app/fulframe_app.dart';

import '../application/task_list_view_model.dart';
import '../domain/task_repository.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({
    required this.repository,
    super.key,
  });

  final TaskRepository repository;

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  late final TaskListViewModel _viewModel;
  final TextEditingController _taskTitleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = TaskListViewModel(repository: widget.repository);
    _viewModel.load();
  }

  @override
  void dispose() {
    _taskTitleController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FulFrame Tasks')),
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, _) {
          if (_viewModel.isLoading) {
            return const FulFrameLoadingState(message: 'Loading tasks...');
          }

          if (_viewModel.error != null && _viewModel.tasks.isEmpty) {
            return FulFrameErrorState(
              message: _viewModel.error!.message,
              onRetry: _viewModel.load,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _taskTitleController,
                        decoration: const InputDecoration(
                          labelText: 'Task title',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _addTask(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Add task',
                      onPressed: _addTask,
                      icon: const Icon(Icons.add_task),
                    ),
                  ],
                ),
              ),
              if (_viewModel.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _viewModel.error!.message,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              Expanded(
                child: _viewModel.isEmpty
                    ? const FulFrameEmptyState(
                        title: 'No tasks yet',
                        message: 'Add a task to see the sample feature.',
                      )
                    : ListView.builder(
                        itemCount: _viewModel.tasks.length,
                        itemBuilder: (context, index) {
                          final task = _viewModel.tasks[index];
                          return ListTile(
                            leading: Icon(
                              task.isComplete
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                            ),
                            title: Text(task.title),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addTask() async {
    await _viewModel.addTask(_taskTitleController.text);
    if (_viewModel.error == null) {
      _taskTitleController.clear();
    }
  }
}
