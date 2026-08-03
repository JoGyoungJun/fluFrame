import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/upgrader.dart';
import 'package:fluframe/src/version.dart';
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
      final code = await upgrader().run(projectDir: project, apply: true);

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

      await upgrader().run(projectDir: project, apply: true);

      final content = File(
        p.join(project.path, 'lib', 'a.dart'),
      ).readAsStringSync();
      expect(log.toString(), contains('(CONFLICT)'));
      expect(content, contains('<<<<<<<'));
      expect(content, contains('alpha local edit'));
      expect(content, contains('alpha v2'));
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
