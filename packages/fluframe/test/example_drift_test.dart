import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/example_drift.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('checkExampleDrift', () {
    late Directory sandbox;
    late Directory template;
    late Directory examples;
    late Directory example;

    /// Writes [content] to [relative] under [root], creating parents.
    void write(Directory root, String relative, String content) {
      File(p.join(root.path, relative))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    Map<String, Object?> readArb(Directory root, String locale) =>
        jsonDecode(
              File(
                p.join(root.path, 'lib', 'l10n', 'app_$locale.arb'),
              ).readAsStringSync(),
            )
            as Map<String, Object?>;

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('fluframe_drift_');
      template = Directory(p.join(sandbox.path, 'template'))
        ..createSync(recursive: true);
      examples = Directory(p.join(sandbox.path, 'examples'))
        ..createSync(recursive: true);
      example = Directory(p.join(examples.path, 'todo_app'))
        ..createSync(recursive: true);

      write(template, 'lib/main.dart', '// fluframe_app\nvoid main() {}\n');
      write(example, 'lib/main.dart', '// todo_app\nvoid main() {}\n');

      write(template, 'lib/l10n/app_en.arb', '''
{
  "@@locale": "en",
  "appTitle": "FluFrame App",
  "homeTab": "Home",
  "@homeTab": {
    "description": "Label for the homeTab screen."
  },
  "settingsTab": "Settings"
}
''');
      write(template, 'lib/l10n/app_ko.arb', '''
{
  "@@locale": "ko",
  "appTitle": "FluFrame 앱",
  "homeTab": "홈",
  "settingsTab": "설정"
}
''');

      // The example carries the template's keys, already renamed, plus one
      // of its own.
      write(example, 'lib/l10n/app_en.arb', '''
{
  "@@locale": "en",
  "appTitle": "Todo App",
  "homeTab": "Home",
  "@homeTab": {
    "description": "Label for the homeTab screen."
  },
  "settingsTab": "Settings",
  "todosTab": "Todos"
}
''');
      write(example, 'lib/l10n/app_ko.arb', '''
{
  "@@locale": "ko",
  "appTitle": "Todo App 앱",
  "homeTab": "홈",
  "settingsTab": "설정",
  "todosTab": "할 일"
}
''');
    });

    tearDown(() => sandbox.deleteSync(recursive: true));

    DriftResult run({required bool fix, StringSink? out}) => checkExampleDrift(
      template: template,
      examples: examples,
      fix: fix,
      out: out ?? StringBuffer(),
    );

    test('a synced example reports no drift', () {
      final out = StringBuffer();

      expect(run(fix: false, out: out).drifted, 0, reason: out.toString());
    });

    test('--fix adds a missing key, and a plain run is then clean', () {
      // The exact loop the tool could not close before: a key is added to
      // the template, --fix reported success on everything else, and the
      // ARBs were still missing it.
      final arb = readArb(example, 'en')..remove('settingsTab');
      write(
        example,
        'lib/l10n/app_en.arb',
        '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
      );

      final before = StringBuffer();
      expect(run(fix: false, out: before).drifted, 1);
      expect(before.toString(), contains('missing string'));
      expect(before.toString(), contains('settingsTab'));

      final fixed = run(fix: true);
      expect(fixed.keysAdded, 1);

      final after = StringBuffer();
      expect(run(fix: false, out: after).drifted, 0, reason: after.toString());
    });

    test('--fix carries the @key metadata across with its key', () {
      final arb = readArb(example, 'en')
        ..remove('homeTab')
        ..remove('@homeTab');
      write(
        example,
        'lib/l10n/app_en.arb',
        '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
      );

      run(fix: true);

      final repaired = readArb(example, 'en');
      expect(repaired['homeTab'], 'Home');
      expect(repaired['@homeTab'], {
        'description': 'Label for the homeTab screen.',
      });
    });

    test('--fix never removes a key the example owns', () {
      run(fix: true);

      expect(readArb(example, 'en')['todosTab'], 'Todos');
      expect(readArb(example, 'ko')['todosTab'], '할 일');
    });

    test('--fix preserves the order of keys already present', () {
      final arb = readArb(example, 'en')..remove('appTitle');
      write(
        example,
        'lib/l10n/app_en.arb',
        '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
      );

      run(fix: true);

      final keys = readArb(example, 'en').keys.toList();
      // Everything that was already there keeps its relative order; the
      // re-added key lands at the end rather than shuffling the file.
      expect(keys.indexOf('homeTab'), lessThan(keys.indexOf('settingsTab')));
      expect(keys.indexOf('settingsTab'), lessThan(keys.indexOf('todosTab')));
      expect(keys.last, 'appTitle');
    });

    test('a differing value is reported and left alone', () {
      final arb = readArb(example, 'ko')..['homeTab'] = '홈 화면';
      write(
        example,
        'lib/l10n/app_ko.arb',
        '${const JsonEncoder.withIndent('  ').convert(arb)}\n',
      );

      final out = StringBuffer();
      expect(run(fix: true, out: out).drifted, 1);
      expect(out.toString(), contains('differing string'));
      expect(out.toString(), contains('homeTab'));

      // Overwriting a translation is worse than the drift.
      expect(readArb(example, 'ko')['homeTab'], '홈 화면');
    });

    test('the template value is compared after the rename tokens', () {
      // appTitle is "FluFrame App" in the template and "Todo App" in the
      // example by design. Comparing raw would report every example as
      // drifted on its own name forever.
      final out = StringBuffer();

      expect(run(fix: false, out: out).drifted, 0, reason: out.toString());
      expect(out.toString(), isNot(contains('appTitle')));
    });

    test('a missing locale is created wholesale by --fix', () {
      File(p.join(example.path, 'lib', 'l10n', 'app_ko.arb')).deleteSync();

      final out = StringBuffer();
      expect(run(fix: false, out: out).drifted, 1);
      expect(out.toString(), contains('missing locale'));

      run(fix: true);

      expect(readArb(example, 'ko')['appTitle'], 'Todo App 앱');
    });
  });
}
