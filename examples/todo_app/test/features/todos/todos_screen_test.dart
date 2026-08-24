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

    testWidgets('the list spans a wide window, rows do not', (tester) async {
      // Design spec 005. The body was wrapped in a ContentWidth, which put
      // the ListView inside an Align — and an Align only receives pointer
      // events inside its own box, so on a 1400px window the outer 280px
      // each side ignored the mouse wheel. The rows take that inset as
      // padding instead; the list itself still spans the window.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1400, 900);
      addTearDown(tester.view.reset);

      await tester.pumpApp(
        const TodosScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        ],
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Task');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Scoped to the list: the TextField carries a Scrollable of its own,
      // so a bare find.byType(Scrollable) matches twice on this screen.
      final list = tester.getRect(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      expect(list.left, 0);
      expect(list.right, 1400);

      // 280 of centring inset, and the field lands in the same measure
      // through its own 16pt gutter.
      final row = tester.getRect(find.byType(CheckboxListTile));
      expect(row.left, 280);
      expect(row.right, 1120);
      final field = tester.getRect(find.byType(TextField));
      expect(field.left, 296);
      expect(field.right, 1104);
    });

    testWidgets('a failed add keeps the text and reports it', (tester) async {
      // Regression: the field was cleared unconditionally beside an
      // `unawaited` add, so a store that refused the write ate the todo
      // *and* what the user had typed — and the error went to the zone,
      // where a release build shows nothing at all.
      await tester.pumpApp(
        const TodosScreen(),
        overrides: [
          keyValueStoreProvider.overrideWithValue(
            FailingKeyValueStore(failWrites: true),
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Write announcement');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(find.text('Something went wrong.'), findsOneWidget);
      // Still there to try again with, and nothing was added behind it.
      expect(find.text('Write announcement'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);

      // Drain the snackbar's display timer: one still pending at
      // teardown fails the test (see the #158 note in helpers.dart).
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });
  });
}
