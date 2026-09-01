import 'dart:io';

import 'package:fluframe/src/project_generator.dart';
import 'package:fluframe/src/template_sync.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('syncTemplate', () {
    // Every branch here is a refusal, and none of them had a test: the tool
    // was only ever run end to end against the real checkout, where a
    // missing template, a missing .gitignore and a vanished entry all
    // cannot happen. tool/publish.bat and .github/workflows/publish.yml
    // gate on the exit code these produce.
    late Directory sandbox;
    late Directory repoRoot;
    late Directory packageRoot;
    late Directory template;

    void write(Directory root, String relative, String content) {
      File(p.join(root.path, relative))
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('fluframe_sync_');
      repoRoot = Directory(p.join(sandbox.path, 'repo'))
        ..createSync(recursive: true);
      packageRoot = Directory(p.join(repoRoot.path, 'packages', 'fluframe'))
        ..createSync(recursive: true);
      template = Directory(p.join(repoRoot.path, 'template'))
        ..createSync(recursive: true);

      // Every overlay entry has to be there, or the completeness gate
      // refuses before any of the branches under test are reached.
      for (final entry in overlayEntries) {
        if (entry == '.gitignore') {
          write(template, entry, 'env/*.local.json\n');
        } else if (p.extension(entry).isEmpty) {
          Directory(p.join(template.path, entry)).createSync(recursive: true);
          write(template, '$entry/placeholder.txt', 'x\n');
        } else {
          write(template, entry, 'x\n');
        }
      }
      write(repoRoot, 'template_addons/supabase/repository.dart', '// x\n');
    });

    tearDown(() {
      try {
        sandbox.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can hold locks briefly; leaking a temp dir is harmless.
      }
    });

    int run({void Function()? onSourcesVerified, StringSink? err}) =>
        syncTemplate(
          packageRoot: packageRoot,
          repoRoot: repoRoot,
          out: StringBuffer(),
          err: err ?? StringBuffer(),
          onSourcesVerified: onSourcesVerified,
        );

    test('a complete checkout syncs and exits 0', () {
      final err = StringBuffer();

      expect(run(err: err), 0, reason: err.toString());
      expect(
        File(
          p.join(packageRoot.path, 'templates', 'app', 'pubspec.yaml'),
        ).existsSync(),
        isTrue,
      );
      // The dot-prefixed entries ship under their dot-less names.
      expect(
        File(
          p.join(packageRoot.path, 'templates', 'app', 'gitignore'),
        ).existsSync(),
        isTrue,
      );
    });

    test('a missing repo template is a refusal, not an empty bundle', () {
      template.deleteSync(recursive: true);
      final err = StringBuffer();

      expect(run(err: err), 1);
      expect(err.toString(), contains('Repo template not found'));
      expect(
        Directory(p.join(packageRoot.path, 'templates')).existsSync(),
        isFalse,
        reason: 'nothing may be written before the checkout is verified',
      );
    });

    test('a missing template/.gitignore refuses to sync', () {
      // It is the sync's only secret filter, so a bundle built without it
      // would be built with no filter at all.
      File(p.join(template.path, '.gitignore')).deleteSync();
      final err = StringBuffer();

      expect(run(err: err), 1);
      expect(err.toString(), contains('refusing to sync'));
    });

    test('missing bundle sources refuse before anything is written', () {
      Directory(
        p.join(repoRoot.path, 'template_addons'),
      ).deleteSync(recursive: true);
      final err = StringBuffer();

      expect(run(err: err), 1);
      expect(err.toString(), contains('MISSING BUNDLE SOURCES'));
      expect(
        Directory(p.join(packageRoot.path, 'templates')).existsSync(),
        isFalse,
      );
    });

    test('an entry that vanishes mid-run fails the whole sync', () {
      // The exit code is assigned and never lowered: everything after the
      // vanished entry succeeds, the secret scan at the end comes back
      // clean, and the run must still fail — publish.bat gates on it, and
      // a pub.dev version can never be replaced once uploaded.
      final err = StringBuffer();

      final code = run(
        err: err,
        onSourcesVerified: () =>
            File(p.join(template.path, 'l10n.yaml')).deleteSync(),
      );

      expect(code, 1);
      expect(err.toString(), contains('vanished during the sync'));
      expect(err.toString(), contains('l10n.yaml'));
      // The clean scan is what used to reset this to 0.
      expect(err.toString(), isNot(contains('SECRET-LIKE FILES')));
    });

    test('a secret-like file in the template never reaches the bundle', () {
      write(template, 'env/dev.local.json', '{"token": "real"}\n');
      final err = StringBuffer();

      expect(run(err: err), 0, reason: err.toString());
      expect(
        File(
          p.join(
            packageRoot.path,
            'templates',
            'app',
            'env',
            'dev.local.json',
          ),
        ).existsSync(),
        isFalse,
      );
    });
  });
}
