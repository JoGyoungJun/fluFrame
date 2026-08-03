import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('rewriteTemplateContent', () {
    test('replaces the package name and display name tokens', () {
      const content = '''
import 'package:fluframe_app/app/app.dart';
// Title: FluFrame App
''';

      final rewritten = rewriteTemplateContent(
        content,
        projectName: 'my_cool_app',
      );

      expect(rewritten, contains("'package:my_cool_app/app/app.dart'"));
      expect(rewritten, contains('// Title: My Cool App'));
      expect(rewritten, isNot(contains('fluframe_app')));
    });

    test('replaces the Japanese display name token', () {
      const content = '"appTitle": "FluFrame アプリ"';

      final rewritten = rewriteTemplateContent(
        content,
        projectName: 'my_cool_app',
      );

      expect(rewritten, '"appTitle": "My Cool App アプリ"');
    });

    test('replaces the Korean display name token', () {
      // Regression: app_ko.arb's appTitle ("FluFrame 앱") used to survive
      // generation, leaving fluFrame branding in the Korean locale.
      const content = '"appTitle": "FluFrame 앱"';

      final rewritten = rewriteTemplateContent(
        content,
        projectName: 'my_cool_app',
      );

      expect(rewritten, '"appTitle": "My Cool App 앱"');
    });
  });

  group('ProjectGenerator.generate', () {
    late Directory temp;
    late Directory templateDir;
    late List<(String, List<String>, String?)> calls;
    late ProjectGenerator generator;
    final log = StringBuffer();

    Future<ProcessResult> fakeRunProcess(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    }) async {
      calls.add((executable, arguments, workingDirectory));
      return ProcessResult(0, 0, '', '');
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fluframe_test_');
      templateDir = Directory(p.join(temp.path, 'template'))..createSync();
      File(p.join(templateDir.path, 'pubspec.yaml')).writeAsStringSync('''
name: fluframe_app
description: "A production-ready Flutter application."
version: 0.1.0+1
''');
      Directory(p.join(templateDir.path, 'lib')).createSync();
      File(p.join(templateDir.path, 'lib', 'main.dart')).writeAsStringSync(
        "import 'package:fluframe_app/app.dart'; // FluFrame App\n",
      );
      // Bundled layout stores .gitignore dot-less.
      File(
        p.join(templateDir.path, 'gitignore'),
      ).writeAsStringSync('env/*.local.json\n');
      calls = [];
      log.clear();
      generator = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: fakeRunProcess,
        log: log,
      );
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can hold locks briefly; leaking a temp dir is harmless.
      }
    });

    test('runs flutter create with the expected arguments', () async {
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(code, 0);
      expect(calls.first.$1, 'flutter');
      expect(
        calls.first.$2,
        containsAllInOrder([
          'create',
          p.join(temp.path, 'demo_app'),
          '--project-name',
          'demo_app',
          '--org',
          'dev.example',
        ]),
      );
      expect(calls.first.$2, contains('--empty'));
    });

    test('overlays template files with tokens rewritten', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      final main = File(
        p.join(temp.path, 'demo_app', 'lib', 'main.dart'),
      ).readAsStringSync();
      expect(main, contains("'package:demo_app/app.dart'"));
      expect(main, contains('// Demo App'));

      final pubspec = File(
        p.join(temp.path, 'demo_app', 'pubspec.yaml'),
      ).readAsStringSync();
      expect(pubspec, contains('name: demo_app'));
    });

    test('restores the dot-less bundled gitignore as .gitignore', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      final gitignore = File(
        p.join(temp.path, 'demo_app', '.gitignore'),
      );
      expect(gitignore.existsSync(), isTrue);
      expect(gitignore.readAsStringSync(), contains('env/*.local.json'));
    });

    test(
      'warns about missing overlay entries instead of silently skipping',
      () async {
        // Regression: a template stripped by packaging (e.g. the unanchored
        // .pubignore test/ pattern) used to produce a "successful" project
        // with entire directories silently absent.
        await generator.generate(
          name: 'demo_app',
          org: 'dev.example',
          outputDirectory: temp.path,
        );

        expect(log.toString(), contains('Warning: template entry "test"'));
      },
    );

    test('writes a custom description into pubspec.yaml', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        description: 'My shiny app.',
      );

      final pubspec = File(
        p.join(temp.path, 'demo_app', 'pubspec.yaml'),
      ).readAsStringSync();
      expect(pubspec, contains('description: "My shiny app."'));
    });

    test(
      'escapes quotes, backslashes, and newlines in the description',
      () async {
        // Regression: an unescaped description like `The "best" app` used to
        // produce unparseable YAML in the generated pubspec.
        await generator.generate(
          name: 'demo_app',
          org: 'dev.example',
          outputDirectory: temp.path,
          description: 'The "best" C:\\app\nfor everyone',
        );

        final pubspec = File(
          p.join(temp.path, 'demo_app', 'pubspec.yaml'),
        ).readAsStringSync();
        expect(
          pubspec,
          contains(r'description: "The \"best\" C:\\app for everyone"'),
        );
      },
    );

    test('runs pub get, dart fix, and gen-l10n by default', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      final argLists = calls.map((call) => call.$2.join(' ')).toList();
      expect(argLists, contains('pub get'));
      expect(argLists, contains('fix --apply'));
      expect(argLists, contains('gen-l10n'));
    });

    test('skips pub get when runPub is false', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        runPub: false,
      );

      expect(calls, hasLength(1));
    });

    test('explains when launching flutter throws ProcessException', () async {
      final failing = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: (executable, arguments, {workingDirectory}) =>
            throw const ProcessException('flutter', ['create']),
        log: log,
      );

      final code = await failing.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(code, 69);
      expect(log.toString(), contains('Flutter SDK not found on PATH'));
      expect(
        log.toString(),
        contains('https://docs.flutter.dev/get-started/install'),
      );
    });

    test('explains when the shell reports flutter as unrecognized', () async {
      // Windows runInShell path: missing command = exit 9009, no exception.
      final failing = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: (executable, arguments, {workingDirectory}) async =>
            ProcessResult(
              0,
              9009,
              '',
              "'flutter' is not recognized as an internal or external command",
            ),
        log: log,
      );

      final code = await failing.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(code, 69);
      expect(log.toString(), contains('Flutter SDK not found on PATH'));
    });

    test('applies a backend addon: files, patches, dependencies', () async {
      Directory(
        p.join(temp.path, 'template_addons', 'fake', 'lib'),
      ).createSync(recursive: true);
      File(
        p.join(temp.path, 'template_addons', 'fake', 'lib', 'extra.dart'),
      ).writeAsStringSync('// extra for fluframe_app\n');
      const fake = BackendAddon(
        name: 'fake',
        dependencies: ['fake_pkg'],
        patches: [
          AddonPatch(
            file: 'lib/main.dart',
            anchor: '// FluFrame App',
            replacement: '// patched by addon',
          ),
        ],
      );
      final withAddon = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: fakeRunProcess,
        log: log,
        addons: const {'fake': fake},
      );

      final code = await withAddon.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        backend: 'fake',
      );

      expect(code, 0, reason: log.toString());
      expect(
        File(
          p.join(temp.path, 'demo_app', 'lib', 'extra.dart'),
        ).readAsStringSync(),
        contains('demo_app'),
      );
      expect(
        File(
          p.join(temp.path, 'demo_app', 'lib', 'main.dart'),
        ).readAsStringSync(),
        contains('// patched by addon'),
      );
      expect(
        calls.map((call) => call.$2.join(' ')),
        contains('pub add fake_pkg'),
      );
    });

    test('a missing patch anchor fails loudly', () async {
      Directory(
        p.join(temp.path, 'template_addons', 'fake'),
      ).createSync(recursive: true);
      const fake = BackendAddon(
        name: 'fake',
        dependencies: [],
        patches: [
          AddonPatch(
            file: 'lib/main.dart',
            anchor: 'THIS ANCHOR DOES NOT EXIST',
            replacement: 'x',
          ),
        ],
      );
      final withAddon = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: fakeRunProcess,
        log: log,
        addons: const {'fake': fake},
      );

      final code = await withAddon.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        backend: 'fake',
      );

      expect(code, isNot(0));
      expect(log.toString(), contains('anchor not found'));
      expect(log.toString(), contains('lib/main.dart'));
    });

    test('an unknown backend is a usage error', () async {
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        backend: 'nope',
      );

      expect(code, 64);
      expect(calls, isEmpty);
    });

    test('refuses to overwrite an existing directory', () async {
      Directory(p.join(temp.path, 'demo_app')).createSync();

      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(code, isNot(0));
      expect(calls, isEmpty);
    });
  });
}
