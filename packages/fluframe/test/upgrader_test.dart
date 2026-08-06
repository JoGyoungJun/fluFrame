import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/upgrader.dart';
import 'package:fluframe/src/version.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Upgrader', () {
    late Directory temp;
    late Directory oldTemplates;
    late Directory newTemplate;
    late Directory project;
    final log = StringBuffer();

    void writeFile(String root, String relative, String content) {
      File(p.join(root, relative))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    Upgrader upgrader() {
      log.clear();
      return Upgrader(
        currentTemplate: newTemplate,
        oldBundleProvider: (version) async => oldTemplates,
        log: log,
      );
    }

    /// Turns [dir] into a git repository with a clean working tree, which
    /// is what `--apply` requires when `--force` is not passed.
    Future<void> gitCommitAll(Directory dir) async {
      Future<void> git(List<String> arguments) async {
        final result = await Process.run(
          'git',
          arguments,
          workingDirectory: dir.path,
          runInShell: true,
        );
        expect(result.exitCode, 0, reason: result.stderr.toString());
      }

      await git(['init', '--quiet']);
      await git(['config', 'core.autocrlf', 'false']);
      await git(['config', 'user.email', 'test@example.com']);
      await git(['config', 'user.name', 'fluframe test']);
      await git(['config', 'commit.gpgsign', 'false']);
      await git(['add', '-A']);
      await git(['commit', '--quiet', '-m', 'before upgrade']);
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fluframe_up_test_');
      // Old bundle: templates/app with one file that will change, one
      // that will be removed upstream.
      oldTemplates = Directory(p.join(temp.path, 'old', 'templates'))
        ..createSync(recursive: true);
      final oldApp = p.join(oldTemplates.path, 'app');
      writeFile(oldApp, 'pubspec.yaml', 'name: fluframe_app\n');
      writeFile(oldApp, 'lib/a.dart', 'alpha\n');
      writeFile(oldApp, 'lib/gone.dart', 'legacy\n');
      // Current template: a.dart changed, b.dart added, gone.dart gone.
      newTemplate = Directory(p.join(temp.path, 'new', 'templates', 'app'))
        ..createSync(recursive: true);
      writeFile(newTemplate.path, 'pubspec.yaml', 'name: fluframe_app\n');
      writeFile(newTemplate.path, 'lib/a.dart', 'alpha v2\n');
      writeFile(newTemplate.path, 'lib/b.dart', 'brand new\n');
      // The user's app, generated from the old bundle (name demo_app).
      project = Directory(p.join(temp.path, 'demo_app'))..createSync();
      writeFile(project.path, 'pubspec.yaml', 'name: demo_app\n');
      writeFile(project.path, 'lib/a.dart', 'alpha\n');
      writeFile(project.path, 'lib/gone.dart', 'legacy\n');
      const meta = {
        'cliVersion': '0.1.0',
        'name': 'demo_app',
        'org': 'dev.example',
        'backend': null,
        'errorReporting': null,
        'analytics': null,
      };
      writeFile(project.path, '.fluframe.json', '${jsonEncode(meta)}\n');
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can hold locks briefly; leaking a temp dir is harmless.
      }
    });

    test('dry run classifies without touching files', () async {
      final code = await upgrader().run(projectDir: project);

      expect(code, 0, reason: log.toString());
      final report = log.toString();
      expect(report, contains('~ lib/a.dart'));
      expect(report, contains('+ lib/b.dart'));
      expect(report, contains('- lib/gone.dart'));
      expect(report, contains('Dry run'));
      // Untouched on disk:
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha\n',
      );
      expect(File(p.join(project.path, 'lib', 'b.dart')).existsSync(), false);
    });

    test('--apply writes clean merges and additions, keeps removals', () async {
      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, 0, reason: log.toString());
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
      expect(
        File(p.join(project.path, 'lib', 'b.dart')).readAsStringSync(),
        'brand new\n',
      );
      // Removed upstream but never deleted locally:
      expect(
        File(p.join(project.path, 'lib', 'gone.dart')).existsSync(),
        isTrue,
      );
      // Metadata bumped:
      expect(
        File(p.join(project.path, '.fluframe.json')).readAsStringSync(),
        contains('"cliVersion": "$cliVersion"'),
      );
    });

    test('local + upstream edits produce conflict markers on apply', () async {
      File(
        p.join(project.path, 'lib', 'a.dart'),
      ).writeAsStringSync('alpha local edit\n');

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      final content = File(
        p.join(project.path, 'lib', 'a.dart'),
      ).readAsStringSync();
      expect(log.toString(), contains('(CONFLICT)'));
      expect(content, contains('<<<<<<<'));
      expect(content, contains('alpha local edit'));
      expect(content, contains('alpha v2'));
      // Unresolved conflicts are a failure, not a success (CI must see it).
      expect(code, ExitCode.software.code, reason: log.toString());
      // And the version must NOT advance, or the `already up to date`
      // short-circuit would seal off the re-run that resolves them.
      final meta = File(
        p.join(project.path, '.fluframe.json'),
      ).readAsStringSync();
      expect(meta, contains('"cliVersion":"0.1.0"'));
      expect(meta, isNot(contains(cliVersion)));

      // Re-running after resolving the markers must still do the upgrade.
      File(
        p.join(project.path, 'lib', 'a.dart'),
      ).writeAsStringSync('alpha v2\n');
      final second = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );
      expect(second, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(project.path, '.fluframe.json')).readAsStringSync(),
        contains('"cliVersion": "$cliVersion"'),
      );
    });

    test('preserves non-ASCII content through a clean merge', () async {
      // Regression: the merged bytes used to travel back through a pipe
      // decoded with the OS codepage (cp949 on Korean Windows), which
      // destroyed every multi-byte character — and the closing quote with
      // it, leaving `Unterminated string literal`.
      const korean = "  expect(find.text('한국어'), findsOneWidget);\n";
      const japanese = "  expect(find.text('日本語'), findsOneWidget);\n";
      // base == ours, upstream appends a line -> clean merge path.
      writeFile(p.join(oldTemplates.path, 'app'), 'test/l.dart', korean);
      writeFile(newTemplate.path, 'test/l.dart', korean + japanese);
      writeFile(project.path, 'test/l.dart', korean);

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      final merged = File(
        p.join(project.path, 'test', 'l.dart'),
      ).readAsStringSync();
      expect(merged, contains('한국어'));
      expect(merged, contains('日本語'));
      expect(merged, isNot(contains('?')));
      expect(merged, isNot(contains('�')));
    });

    test('a file the user deleted is reported, not resurrected', () async {
      // Regression: a locally deleted file was indistinguishable from a
      // new one, so --apply brought it back. Worse for a rename — the
      // original returned alongside the copy, declaring the same class
      // twice, and the report showed both as plain `+`.
      File(p.join(project.path, 'lib', 'a.dart')).deleteSync();

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).existsSync(),
        isFalse,
      );
      expect(log.toString(), contains('deleted locally - not restored'));
      // A genuinely new file is still added.
      expect(
        File(p.join(project.path, 'lib', 'b.dart')).readAsStringSync(),
        'brand new\n',
      );
    });

    test('--restore-deleted brings it back on request', () async {
      File(p.join(project.path, 'lib', 'a.dart')).deleteSync();

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
        restoreDeleted: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
    });

    test('--apply refuses when the app is not a git repository', () async {
      final code = await upgrader().run(projectDir: project, apply: true);

      expect(code, ExitCode.usage.code, reason: log.toString());
      expect(log.toString(), contains('not a git repository'));
      // Nothing was written.
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha\n',
      );
      expect(File(p.join(project.path, 'lib', 'b.dart')).existsSync(), isFalse);
    });

    test('--apply refuses on a dirty git working tree', () async {
      await gitCommitAll(project);
      File(
        p.join(project.path, 'lib', 'a.dart'),
      ).writeAsStringSync('alpha uncommitted\n');

      final code = await upgrader().run(projectDir: project, apply: true);

      expect(code, ExitCode.usage.code, reason: log.toString());
      expect(log.toString(), contains('uncommitted changes'));
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha uncommitted\n',
      );
    });

    test('--apply proceeds on a clean git working tree', () async {
      await gitCommitAll(project);

      final code = await upgrader().run(projectDir: project, apply: true);

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
    });

    test('already up to date short-circuits', () async {
      final meta = {
        'cliVersion': cliVersion,
        'name': 'demo_app',
        'org': 'dev.example',
      };
      File(
        p.join(project.path, '.fluframe.json'),
      ).writeAsStringSync('${jsonEncode(meta)}\n');

      final code = await upgrader().run(projectDir: project);

      expect(code, 0);
      expect(log.toString(), contains('nothing to upgrade'));
    });

    test('missing metadata without --from is a usage error', () async {
      File(p.join(project.path, '.fluframe.json')).deleteSync();

      final code = await upgrader().run(projectDir: project);

      expect(code, 64);
      expect(log.toString(), contains('--from'));
    });
  });
}
