import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/features/home/presentation/home_screen.dart';

import '../../helpers/helpers.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders the intro and the counter', (tester) async {
      await tester.pumpApp(const HomeScreen());

      expect(find.text('Welcome to Todo App!'), findsOneWidget);
      expect(find.text('Button pushed 0 times'), findsOneWidget);
    });

    testWidgets('tapping increment updates the counter', (tester) async {
      await tester.pumpApp(const HomeScreen());

      await tester.tap(find.text('Increment'));
      await tester.pump();

      // Regression: counterLabel is an ICU plural — one tap must read
      // "1 time", not the ungrammatical "1 times".
      expect(find.text('Button pushed 1 time'), findsOneWidget);
    });
  });
}
