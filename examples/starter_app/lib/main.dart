import 'package:flutter/material.dart';
import 'package:fulframe_app/fulframe_app.dart';

import 'features/task_list/data/in_memory_task_repository.dart';
import 'features/task_list/ui/task_list_screen.dart';

void main() {
  runApp(
    const FulFrameAppShell(
      child: StarterApp(),
    ),
  );
}

class StarterApp extends StatelessWidget {
  const StarterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FulFrame Starter',
      theme: ThemeData(useMaterial3: true),
      home: const StarterHomePage(),
    );
  }
}

class StarterHomePage extends StatelessWidget {
  const StarterHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return TaskListScreen(
      repository: InMemoryTaskRepository(),
    );
  }
}
