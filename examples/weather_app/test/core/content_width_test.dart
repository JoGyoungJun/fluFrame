import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_app/core/widgets/content_width.dart';

/// A body shaped like `post_detail_screen`'s: a scroll view whose column
/// shrink-wraps and left-aligns. It is the shape that breaks if the cap
/// loosens constraints the wrong way.
class _DetailBody extends StatelessWidget {
  const _DetailBody({this.long = true});

  final bool long;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('title', key: Key('title')),
        Text(long ? 'body ' * 400 : 'short'),
      ],
    ),
  );
}

void main() {
  Future<void> resize(WidgetTester tester, double width, double height) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester, Widget body) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(appBar: AppBar(), body: body),
    ),
  );

  group('ContentWidth', () {
    testWidgets('caps a wide child at 840', (tester) async {
      await resize(tester, 1400, 900);

      await pump(
        tester,
        const ContentWidth(child: SizedBox.expand(key: Key('child'))),
      );

      expect(tester.getSize(find.byKey(const Key('child'))).width, 840);
    });

    testWidgets('is inert below the cap', (tester) async {
      await resize(tester, 390, 844);

      await pump(
        tester,
        const ContentWidth(child: SizedBox.expand(key: Key('child'))),
      );

      expect(tester.getSize(find.byKey(const Key('child'))).width, 390);
    });

    testWidgets('honours an explicit maxWidth', (tester) async {
      await resize(tester, 1400, 900);

      await pump(
        tester,
        const ContentWidth(
          maxWidth: 400,
          child: SizedBox.expand(key: Key('child')),
        ),
      );

      expect(tester.getSize(find.byKey(const Key('child'))).width, 400);
    });

    testWidgets('leaves a detail-shaped body exactly where it was at phone '
        'width', (tester) async {
      // Not just the same width — the same offset. `Center` would pass
      // this on width and still drop the content to the middle of the
      // screen, which is how the first draft of spec 005 was wrong.
      await resize(tester, 390, 844);
      for (final long in [true, false]) {
        await pump(tester, _DetailBody(long: long));
        final before = tester.getRect(find.byKey(const Key('title')));

        await pump(tester, ContentWidth(child: _DetailBody(long: long)));
        final after = tester.getRect(find.byKey(const Key('title')));

        expect(after, before, reason: 'long=$long');
      }
    });

    testWidgets('keeps a short body top-anchored and left-aligned when wide', (
      tester,
    ) async {
      await resize(tester, 1400, 900);

      await pump(tester, const ContentWidth(child: _DetailBody(long: false)));
      final title = tester.getRect(find.byKey(const Key('title')));

      // 280 of inset + the body's own 24 of padding, and the same top as
      // an unwrapped body: the cap centres horizontally and nothing else.
      expect(title.left, 304);
      expect(title.top, 80);
    });
  });

  group('ContentWidth.insetFor', () {
    test('centres the cap inside a wider window', () {
      expect(ContentWidth.insetFor(1400), 280);
    });

    test('is zero at and below the cap', () {
      expect(ContentWidth.insetFor(840), 0);
      expect(ContentWidth.insetFor(390), 0);
    });

    test('honours an explicit cap', () {
      expect(ContentWidth.insetFor(1400, 400), 500);
    });
  });
}
