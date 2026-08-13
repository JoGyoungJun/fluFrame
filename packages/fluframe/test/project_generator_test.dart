import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:io/io.dart';
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

    test('leaves no fluFrame branding in the real template sources', () {
      // Regression: the rewriter only replaces four exact tokens, so
      // `Welcome to fluFrame!` (lowercase f) and `class FluFrameApp`
      // sailed through — every generated app greeted its users with the
      // template's name. Walk the actual shipped sources rather than a
      // fixture, because the fixture is what let this through.
      final branding = RegExp('flu_?frame', caseSensitive: false);
      // An explicit link back to the project is attribution, not leftover
      // template prose; a bare mention of "the fluFrame repository" in a
      // generated app's source is the latter.
      final attributionLink = RegExp(
        r'https://github\.com/JoGyoungJun/fluFrame\S*',
      );
      // The `add feature` anchors are the same kind of exception: they are
      // a contract token the CLI greps for, so they MUST survive rewriting
      // verbatim (spec 003). Only the bare anchor line is allowed — prose
      // on the same line would smuggle template branding back in, which is
      // what this test exists to stop.
      final scaffoldAnchor = RegExp(
        r'^\s*// fluframe:(routes|branches|destinations)$',
      );
      // The CLI's own name is not leftover template prose when it names
      // something that exists inside the user's project: a command they run
      // (`fluframe upgrade`), the anchors the scaffolder greps for — quoted
      // in prose here, not just on their own line — or the metadata file
      // written to their project root. Those are theirs, the way `flutter`
      // and `dart` are. Kept to exactly these shapes rather than loosened:
      // `Welcome to fluFrame!` must still fail.
      final cliSurface = RegExp(
        r'`?\.fluframe\.json`?'
        '|fluframe:(routes|branches|destinations)'
        r'|fluframe (create|doctor|upgrade|add)\b',
      );
      final rewritable = {'.dart', '.arb', '.yaml', '.yml', '.json', '.md'};
      final leaks = <String>[];

      for (final root in [
        '../../template/lib',
        '../../template/test',
      ]) {
        final entities = FileSystemEntity.isDirectorySync(root)
            ? Directory(root).listSync(recursive: true)
            : <FileSystemEntity>[File(root)];
        for (final entity in entities) {
          if (entity is! File) continue;
          if (!rewritable.contains(p.extension(entity.path))) continue;
          final rewritten = rewriteTemplateContent(
            entity.readAsStringSync(),
            projectName: 'my_cool_app',
          );
          for (final (index, line) in rewritten.split('\n').indexed) {
            if (scaffoldAnchor.hasMatch(line.trimRight())) continue;
            final prose = line
                .replaceAll(attributionLink, '')
                .replaceAll(cliSurface, '');
            if (branding.hasMatch(prose)) {
              leaks.add('${p.relative(entity.path)}:${index + 1}: $line');
            }
          }
        }
      }

      expect(
        leaks,
        isEmpty,
        reason:
            'These lines reach a generated app verbatim. Spell one of the '
            'rename tokens (fluframe_app / FluFrame App / FluFrame 앱 / '
            'FluFrame アプリ) so the CLI rewrites them, or drop the '
            'reference:\n${leaks.join('\n')}',
      );
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
      Directory(p.join(templateDir.path, 'test')).createSync();
      File(
        p.join(templateDir.path, 'test', 'app_test.dart'),
      ).writeAsStringSync('// FluFrame App smoke test\n');
      // Bundled layout stores dot-prefixed entries dot-less.
      File(
        p.join(templateDir.path, 'gitignore'),
      ).writeAsStringSync('env/*.local.json\n');
      Directory(
        p.join(templateDir.path, 'github', 'workflows'),
      ).createSync(recursive: true);
      File(
        p.join(templateDir.path, 'github', 'workflows', 'ci.yml'),
      ).writeAsStringSync('name: CI\n');
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

    test('restores the dot-less bundled github dir as .github', () async {
      // Without the remap the generated app ships no CI at all: the bundle
      // cannot carry a literal `.github`, because pub would then register
      // the template's workflows on the repository publishing the CLI.
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      final workflow = File(
        p.join(temp.path, 'demo_app', '.github', 'workflows', 'ci.yml'),
      );
      expect(workflow.existsSync(), isTrue, reason: log.toString());
      expect(workflow.readAsStringSync(), contains('name: CI'));
      expect(
        Directory(p.join(temp.path, 'demo_app', 'github')).existsSync(),
        isFalse,
        reason: 'the bundled spelling must not survive into the app',
      );
    });

    test('every dot-prefixed overlay entry has a bundled name', () {
      // The bundle cannot contain dotfiles that tooling would act on, so
      // adding e.g. `.vscode` to overlayEntries without a remap silently
      // drops it from every published release.
      expect(
        overlayEntries.where((entry) => entry.startsWith('.')),
        everyElement(isIn(bundledOverlayNames.keys)),
      );
    });

    test('warns about a missing optional overlay entry', () async {
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      // env/ is absent from this fixture but an app runs without it.
      expect(code, 0);
      expect(log.toString(), contains('Warning: template entry "env"'));
    });

    for (final entry in requiredOverlayEntries) {
      test('fails when the bundle is missing "$entry"', () async {
        // Regression: a template stripped by packaging (e.g. the unanchored
        // .pubignore `test/` pattern that once removed templates/app/test)
        // used to produce a "successful" project with entire directories
        // absent — and the overlay deletes the scaffold's lib/ first, so a
        // missing lib/ left no source at all.
        final source = p.join(templateDir.path, entry);
        if (FileSystemEntity.isDirectorySync(source)) {
          Directory(source).deleteSync(recursive: true);
        } else {
          File(source).deleteSync();
        }

        final code = await generator.generate(
          name: 'demo_app',
          org: 'dev.example',
          outputDirectory: temp.path,
        );

        expect(code, ExitCode.software.code, reason: log.toString());
        final report = log.toString();
        expect(report, contains('bundle is incomplete'));
        expect(report, contains(entry));
        expect(report, contains('dart pub global activate fluframe'));
        // And the user is told how to retry.
        expect(report, contains('Partial output left at:'));
      });
    }

    test('points at the partial output when pub get fails', () async {
      // Regression: exit 70 left 230 files behind and the obvious retry hit
      // `Directory "..." already exists. Aborting.` with no explanation.
      final generator = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: (executable, arguments, {workingDirectory}) async {
          calls.add((executable, arguments, workingDirectory));
          return arguments.join(' ') == 'pub get'
              ? ProcessResult(
                  0,
                  1,
                  '',
                  'Building with plugins requires '
                      'symlink support.',
                )
              : ProcessResult(0, 0, '', '');
        },
        log: log,
      );

      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(code, ExitCode.software.code);
      final report = log.toString();
      expect(report, contains('flutter pub get failed'));
      expect(report, contains('Partial output left at:'));
      expect(report, contains(p.join(temp.path, 'demo_app')));
      if (Platform.isWindows) {
        // The one failure mode a Windows user cannot diagnose alone.
        expect(report, contains('Developer Mode'));
      }
      // A half-generated app must not look upgradable.
      expect(
        File(p.join(temp.path, 'demo_app', '.fluframe.json')).existsSync(),
        isFalse,
      );
    });

    test('keeps warnings from dart fix and gen-l10n non-fatal', () async {
      final generator = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: (executable, arguments, {workingDirectory}) async {
          final joined = arguments.join(' ');
          return joined == 'fix --apply' || joined == 'gen-l10n'
              ? ProcessResult(0, 1, '', 'boom')
              : ProcessResult(0, 0, '', '');
        },
        log: log,
      );

      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(code, 0, reason: log.toString());
      expect(log.toString(), contains('Warning: dart fix failed'));
      expect(log.toString(), contains('flutter gen-l10n failed'));
    });

    test('uses the documented default platforms', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
      );

      expect(
        calls.first.$2,
        contains('--platforms=${defaultPlatforms.join(',')}'),
      );
      expect(
        defaultPlatforms,
        ['android', 'ios', 'web', 'windows', 'macos', 'linux'],
        reason: 'the README and e2e document this exact set',
      );
    });

    test('passes an explicit platform list through', () async {
      await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        platforms: const ['web'],
      );

      expect(calls.first.$2, contains('--platforms=web'));
    });

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
      // Dependencies are written into pubspec.yaml textually, never via
      // `pub add` — that keeps the bare merge base identical to a created
      // app and works offline (#180, #181).
      expect(
        File(
          p.join(temp.path, 'demo_app', 'pubspec.yaml'),
        ).readAsStringSync(),
        contains('  fake_pkg: any'),
      );
      expect(
        calls.map((call) => call.$2.join(' ')),
        isNot(contains('pub add fake_pkg')),
      );
    });

    test('--no-pub skips addon pub add and says what is missing', () async {
      // Regression: --no-pub skipped `pub get` but still ran one
      // `pub add` per addon, so the flag resolved over the network
      // anyway — the opposite of what it promises.
      Directory(
        p.join(temp.path, 'template_addons', 'fake', 'lib'),
      ).createSync(recursive: true);
      const fake = BackendAddon(
        name: 'fake',
        dependencies: ['fake_pkg:^1.2.3'],
        patches: [],
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
        runPub: false,
      );

      expect(code, 0, reason: log.toString());
      // flutter create and nothing else.
      expect(calls, hasLength(1));
      // The dependency is already in pubspec.yaml with its caret intact —
      // the printed `pub add "pkg:^x"` step is gone, because every shell
      // but cmd.exe stripped the quotes and the batch re-parse ate the
      // caret, silently writing exact pins (#181).
      expect(
        File(
          p.join(temp.path, 'demo_app', 'pubspec.yaml'),
        ).readAsStringSync(),
        contains('  fake_pkg: ^1.2.3'),
      );
      expect(log.toString(), contains('flutter pub get'));
      expect(log.toString(), isNot(contains('pub add')));
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

    test(
      'stacks a backend addon with a patch-only error-reporting addon',
      () async {
        Directory(
          p.join(temp.path, 'template_addons', 'fake', 'lib'),
        ).createSync(recursive: true);
        File(
          p.join(temp.path, 'template_addons', 'fake', 'lib', 'extra.dart'),
        ).writeAsStringSync('// extra\n');
        const backendFake = BackendAddon(
          name: 'fake',
          dependencies: ['fake_pkg'],
          patches: [
            AddonPatch(
              file: 'lib/main.dart',
              anchor: '// FluFrame App',
              replacement: '// backend-patched',
            ),
          ],
        );
        const reportingFake = BackendAddon(
          name: 'fake_report',
          requiresFiles: false,
          dependencies: ['report_pkg'],
          patches: [
            AddonPatch(
              file: 'lib/main.dart',
              anchor: '// backend-patched',
              replacement: '// backend-patched // report-patched',
            ),
          ],
        );
        final stacked = ProjectGenerator(
          templateDirectory: templateDir,
          runProcess: fakeRunProcess,
          log: log,
          addons: const {'fake': backendFake},
          errorAddons: const {'fake_report': reportingFake},
        );

        final code = await stacked.generate(
          name: 'demo_app',
          org: 'dev.example',
          outputDirectory: temp.path,
          backend: 'fake',
          errorReporting: 'fake_report',
        );

        expect(code, 0, reason: log.toString());
        final main = File(
          p.join(temp.path, 'demo_app', 'lib', 'main.dart'),
        ).readAsStringSync();
        expect(main, contains('// backend-patched // report-patched'));
        final argLists = calls.map((call) => call.$2.join(' ')).toList();
        expect(argLists, isNot(contains('pub add fake_pkg')));
        expect(argLists, isNot(contains('pub add report_pkg')));
        final pubspec = File(
          p.join(temp.path, 'demo_app', 'pubspec.yaml'),
        ).readAsStringSync();
        expect(pubspec, contains('  fake_pkg: any'));
        expect(pubspec, contains('  report_pkg: any'));
      },
    );

    test('writes generation metadata (.fluframe.json)', () async {
      Directory(
        p.join(temp.path, 'template_addons', 'fake'),
      ).createSync(recursive: true);
      const fake = BackendAddon(
        name: 'fake',
        requiresFiles: false,
        dependencies: [],
        patches: [],
      );
      final withAddon = ProjectGenerator(
        templateDirectory: templateDir,
        runProcess: fakeRunProcess,
        log: log,
        addons: const {'fake': fake},
      );

      await withAddon.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        backend: 'fake',
      );

      final metadata = File(
        p.join(temp.path, 'demo_app', '.fluframe.json'),
      ).readAsStringSync();
      expect(metadata, contains('"schema": 1'));
      expect(metadata, contains('"name": "demo_app"'));
      expect(metadata, contains('"org": "dev.example"'));
      expect(metadata, contains('"backend": "fake"'));
      expect(metadata, contains('"analytics": null'));
    });

    test('an unknown analytics service is a usage error', () async {
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        analytics: 'nope',
      );

      expect(code, 64);
      expect(calls, isEmpty);
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
