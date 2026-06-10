import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fulframe_starter_app/main.dart';

void main() {
  testWidgets('Starter app renders empty task-list state', (tester) async {
    await tester.pumpWidget(const StarterApp());
    await tester.pumpAndSettle();

    expect(find.text('FulFrame Tasks'), findsOneWidget);
    expect(find.text('No tasks yet'), findsOneWidget);
  });

  testWidgets('Starter app adds a task locally', (tester) async {
    await tester.pumpWidget(const StarterApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Write MVP docs');
    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();

    expect(find.text('Write MVP docs'), findsOneWidget);
  });
}
