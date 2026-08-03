import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/core/storage/key_value_store.dart';
import 'package:todo_app/features/todos/presentation/todos_screen.dart';

import '../../helpers/helpers.dart';

void main() {
  group('TodosScreen', () {
    testWidgets('adds a todo from the input field', (tester) async {
      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const TodosScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Write announcement');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Write announcement'), findsOneWidget);
      expect(
        await store.getString('todos.items'),
        contains('Write announcement'),
      );
    });

    testWidgets('toggling strikes the todo through', (tester) async {
      final store = InMemoryKeyValueStore();
      await tester.pumpApp(
        const TodosScreen(),
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Task');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(await store.getString('todos.items'), contains('"done":true'));
    });
  });
}
