import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/bundle_archive.dart';
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

    test('a truncated bundle stops the upgrade instead of merging against '
        'a partial base', () async {
      // #145 end to end. The merge base for an upgrade is the published
      // bundle of the version the app was generated with, so a bundle that
      // arrives half-inflated does not stay a download problem. Measured
      // against this fixture before the fix, the run *succeeded* and told
      // the user:
      //
      //   Warning: template entry "pubspec.yaml" not found — skipped.  (×16)
      //   Upgrade 0.1.0 -> 1.4.0 (dry run)
      //     ... conflicts: 1
      //     ! lib/a.dart (CONFLICT)
      //   Dry run — re-run with --apply to write these changes.
      //
      // A conflict invented on a file the user never edited, because the
      // partial base disagreed with both sides — then an invitation to
      // apply it.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final registry = Uri.parse('http://127.0.0.1:${server.port}');

      // Big enough that a cut leaves a *partial* archive rather than an
      // empty one — the case that produces a wrong merge rather than a
      // confusing error.
      final full = const GZipEncoder().encodeBytes(
        TarEncoder().encodeBytes(
          Archive()
            ..add(ArchiveFile.string('templates/app/lib/a.dart', 'x' * 40000))
            ..add(
              ArchiveFile.string('templates/app/pubspec.yaml', 'name: x\n'),
            ),
        ),
      );
      // The digest is of what is actually served, so the download passes
      // verification and the truncation is still what stops the upgrade —
      // this test is about a partial archive, not a tampered one.
      final cut = full.sublist(0, 105);
      server.listen((request) {
        final response = request.response;
        if (request.uri.path.startsWith('/api/packages/')) {
          response.write(
            jsonEncode({
              'archive_url': registry
                  .resolve('/archives/cut.tar.gz')
                  .toString(),
              'archive_sha256': sha256.convert(cut).toString(),
            }),
          );
        } else {
          response.add(cut);
        }
        unawaited(response.close());
      });

      log.clear();
      final upgrader = Upgrader(
        currentTemplate: newTemplate,
        oldBundleProvider: (version) => downloadPublishedBundle(
          version,
          registry: registry,
          timeouts: const (
            connect: Duration(seconds: 5),
            metadata: Duration(seconds: 20),
            download: Duration(seconds: 20),
          ),
        ),
        log: log,
      );

      await expectLater(
        upgrader.run(projectDir: project),
        throwsA(
          isA<BundleException>().having(
            (e) => e.message,
            'message',
            contains('arrived incomplete'),
          ),
        ),
      );
      // It must not have reached the classification at all — no invented
      // conflict, and no invitation to apply one.
      final report = log.toString();
      expect(report, isNot(contains('CONFLICT')));
      expect(report, isNot(contains('Dry run')));
    });

    test('refuses to run backwards against a newer app', () async {
      // #167. Only `from == cliVersion` was checked, so an app generated
      // by a NEWER fluframe took its newer bundle as BASE and this CLI's
      // older template as THEIRS. The merge ran in reverse: newer content
      // was reported as a clean merge, overwritten, and .fluframe.json was
      // rewritten DOWN — exit 0, "Applied.", content gone.
      writeFile(project.path, '.fluframe.json', '''
{"cliVersion":"99.0.0","name":"demo_app","org":"dev.example"}
''');
      writeFile(project.path, 'lib/a.dart', 'from the newer template\n');

      // force: true so the git gate does not mask the check under test —
      // without it this test fails pre-fix for the wrong reason.
      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.usage.code, reason: log.toString());
      expect(log.toString(), contains('newer than'));
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'from the newer template\n',
        reason: 'nothing may be overwritten by an older template',
      );
      expect(
        File(p.join(project.path, '.fluframe.json')).readAsStringSync(),
        contains('99.0.0'),
        reason: 'the recorded version must not be rolled back',
      );
    });

    test(
      '--from reads the package name from pubspec, not the folder',
      () async {
        // #168. A checkout directory, a monorepo path like apps/mobile, or a
        // renamed folder is not the Dart package name. Taking the basename
        // wrote imports for a package that does not exist.
        // The added file has to mention the package, or the rename cannot
        // show up at all — with a plain-text body this test passes either
        // way and proves nothing.
        writeFile(
          newTemplate.path,
          'lib/b.dart',
          "import 'package:fluframe_app/a.dart';\n",
        );

        final renamed = Directory(p.join(temp.path, 'checkout-2024'))
          ..createSync();
        writeFile(renamed.path, 'pubspec.yaml', 'name: demo_app\n');
        writeFile(renamed.path, 'lib/a.dart', 'alpha\n');

        final code =
            await Upgrader(
              currentTemplate: newTemplate,
              oldBundleProvider: (version) async => oldTemplates,
              log: log,
            ).run(
              projectDir: renamed,
              fromOverride: '0.1.0',
              apply: true,
              force: true,
            );

        expect(code, isNot(ExitCode.usage.code), reason: log.toString());
        final added = File(
          p.join(renamed.path, 'lib', 'b.dart'),
        ).readAsStringSync();

        expect(
          added,
          contains("import 'package:demo_app/a.dart';"),
          reason: 'the rename must use the package name from pubspec.yaml',
        );
        // `checkout-2024` is not even a legal Dart package name, so the
        // import it used to write could never resolve.
        expect(added, isNot(contains('checkout-2024')));
      },
    );

    test(
      'a conflict resolved by keeping both sides completes on re-run',
      () async {
        // #166. The existing conflict test resolves by writing exactly
        // THEIRS, which is the one resolution that used to work. Keeping any
        // of your own code — the normal outcome — put --apply in a loop: the
        // re-run rebuilt the same BASE, git merge-file saw both sides
        // changed again, and it wrote markers back into the file the user
        // had just fixed, while refusing to advance .fluframe.json.
        File(
          p.join(project.path, 'lib', 'a.dart'),
        ).writeAsStringSync('alpha local edit\n');

        final first = await upgrader().run(
          projectDir: project,
          apply: true,
          force: true,
        );
        expect(first, ExitCode.software.code, reason: log.toString());
        expect(
          File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
          contains('<<<<<<<'),
        );

        // Resolve by combining: equal to neither side.
        const resolved = 'alpha v2 plus my local edit\n';
        File(p.join(project.path, 'lib', 'a.dart')).writeAsStringSync(resolved);

        final second = await upgrader().run(
          projectDir: project,
          apply: true,
          force: true,
        );

        expect(second, ExitCode.success.code, reason: log.toString());
        expect(
          File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
          resolved,
          reason: 'the re-run must not touch what the user resolved',
        );
        final meta =
            jsonDecode(
                  File(
                    p.join(project.path, '.fluframe.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(meta['cliVersion'], cliVersion);
        expect(meta.containsKey('pendingUpgrade'), isFalse);
        expect(meta.containsKey('pendingConflicts'), isFalse);
      },
    );

    test(
      'a re-run with markers still present refuses and names the files',
      () async {
        File(
          p.join(project.path, 'lib', 'a.dart'),
        ).writeAsStringSync('alpha local edit\n');
        await upgrader().run(projectDir: project, apply: true, force: true);

        // The user has not resolved anything yet.
        final second = await upgrader().run(
          projectDir: project,
          apply: true,
          force: true,
        );

        expect(second, ExitCode.software.code, reason: log.toString());
        expect(log.toString(), contains('lib/a.dart'));
        expect(log.toString(), contains('in progress'));
        // And it must not have re-merged: no doubled markers.
        final content = File(
          p.join(project.path, 'lib', 'a.dart'),
        ).readAsStringSync();
        expect('<<<<<<<'.allMatches(content).length, 1);
      },
    );

    test(
      'dry run reports an upgrade in progress instead of re-merging',
      () async {
        File(
          p.join(project.path, 'lib', 'a.dart'),
        ).writeAsStringSync('alpha local edit\n');
        await upgrader().run(projectDir: project, apply: true, force: true);
        File(
          p.join(project.path, 'lib', 'a.dart'),
        ).writeAsStringSync('resolved\n');

        final code = await upgrader().run(projectDir: project);

        expect(code, ExitCode.success.code, reason: log.toString());
        expect(log.toString(), contains('in progress'));
        // A dry run records nothing.
        final meta =
            jsonDecode(
                  File(
                    p.join(project.path, '.fluframe.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(meta['cliVersion'], '0.1.0');
        expect(meta['pendingUpgrade'], cliVersion);
      },
    );

    test('hand-broken .fluframe.json shapes die as sentences', () async {
      // #187: every one of these used to be a TypeError printed as
      // "This is a bug" with a stack trace — for a file the user edits.
      const shapes = {
        '[]': 'not an object',
        '{"cliVersion": 1.4}': 'expected a string',
        '{"cliVersion":"0.1.0","name":["demo"]}': 'expected a string',
        // The three addon keys are read the same way, one screenful
        // further down, and were left out of the loop that guards the
        // rest — so each was still #187, one key over.
        '{"cliVersion":"0.1.0","backend":7}': 'expected a string',
        '{"cliVersion":"0.1.0","errorReporting":7}': 'expected a string',
        '{"cliVersion":"0.1.0","analytics":[]}': 'expected a string',
        '{"cliVersion":"0.1.0","pendingUpgrade":{}}': 'expected a string',
        '{"cliVersion":"0.1.0","pendingUpgrade":"1.9.9",'
                '"pendingConflicts":"lib/a.dart"}':
            'not a list',
      };
      for (final MapEntry(key: json, value: expected) in shapes.entries) {
        writeFile(project.path, '.fluframe.json', '$json\n');

        final code = await upgrader().run(projectDir: project);

        expect(code, ExitCode.data.code, reason: '$json → $log');
        expect(log.toString(), contains(expected), reason: json);
        expect(log.toString(), isNot(contains('This is a bug')));
      }
    });

    test('a cliVersion that is not a version is named, not retried', () async {
      // #189: "abc" reached pub.dev, got a 400, and the user was told
      // "usually temporary — try again in a minute" for a permanent typo.
      writeFile(
        project.path,
        '.fluframe.json',
        '{"cliVersion":"abc","name":"demo_app"}\n',
      );

      final code = await upgrader().run(projectDir: project);

      expect(code, ExitCode.usage.code, reason: log.toString());
      expect(log.toString(), contains('"abc" is not a version number'));
      expect(log.toString(), contains('.fluframe.json'));
      expect(log.toString(), isNot(contains('usually temporary')));
    });

    test(
      'a --from app finishes its pending upgrade without --from again',
      () async {
        // #178: the conflicted apply wrote a .fluframe.json holding ONLY the
        // pending keys, so the instructed plain re-run died on the
        // "No .fluframe.json found" gate — about the very file fluframe had
        // just written.
        File(p.join(project.path, '.fluframe.json')).deleteSync();
        File(
          p.join(project.path, 'lib', 'a.dart'),
        ).writeAsStringSync('alpha local edit\n');

        final first = await upgrader().run(
          projectDir: project,
          fromOverride: '0.1.0',
          apply: true,
          force: true,
        );
        expect(first, ExitCode.software.code, reason: log.toString());
        // The message about the version staying put has to be true: the
        // file now records the version the app is AT.
        final metaAfter =
            jsonDecode(
                  File(
                    p.join(project.path, '.fluframe.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(metaAfter['cliVersion'], '0.1.0');

        // Resolve, then re-run exactly as instructed — no --from.
        File(
          p.join(project.path, 'lib', 'a.dart'),
        ).writeAsStringSync('alpha v2 plus mine\n');
        final second = await upgrader().run(projectDir: project, apply: true);

        expect(second, ExitCode.success.code, reason: log.toString());
        final done =
            jsonDecode(
                  File(
                    p.join(project.path, '.fluframe.json'),
                  ).readAsStringSync(),
                )
                as Map<String, dynamic>;
        expect(done['cliVersion'], cliVersion);
        expect(done.containsKey('pendingUpgrade'), isFalse);
      },
    );

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

    test('the summary counts the user tree, not the template diff', () async {
      // Regression: `unchanged` was incremented on `base == theirs` alone,
      // without ever opening the user's copy — so a file they had
      // rewritten was still reported to them as unchanged.
      writeFile(p.join(oldTemplates.path, 'app'), 'lib/same.dart', 'same\n');
      writeFile(newTemplate.path, 'lib/same.dart', 'same\n');
      writeFile(project.path, 'lib/same.dart', 'same\n');
      writeFile(project.path, 'pubspec.yaml', 'name: demo_app\n# mine\n');

      final code = await upgrader().run(projectDir: project);

      expect(code, ExitCode.success.code, reason: log.toString());
      // lib/same.dart matches the template; pubspec.yaml is the user's.
      expect(log.toString(), contains('up to date: 1'));
      expect(log.toString(), contains('your edits kept: 1'));
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

    test('a run deletes the scratch tree it reconstructs BASE in', () async {
      // Regression: the fluframe_upgrade_ directory holds two whole
      // rebuilt app trees (four when the addon replay falls back) and was
      // never deleted on any path, so every invocation — dry runs
      // included — left a full template behind on the temp volume.
      Set<String> workDirs() => Directory.systemTemp
          .listSync()
          .whereType<Directory>()
          .map((directory) => p.basename(directory.path))
          .where((name) => name.startsWith('fluframe_upgrade_'))
          .toSet();

      final before = workDirs();
      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(workDirs().difference(before), isEmpty);
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
      final meta =
          jsonDecode(
                File(p.join(project.path, '.fluframe.json')).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(meta['cliVersion'], '0.1.0');
      // The target is recorded as pending, not applied: that is what lets
      // the re-run finish instead of re-merging the same base (#166).
      expect(meta['pendingUpgrade'], cliVersion);
      expect(meta['pendingConflicts'], contains('lib/a.dart'));

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

    test('a failed write is a sentence, and records no upgrade', () async {
      // Regression: --apply wrote every merged file in a bare loop and
      // recorded the version only afterwards, so a single failed write
      // escaped as "This is a bug" plus a stack trace and left a tree
      // that was part upgraded, still recorded at the old version, and
      // already carrying conflict markers — which the next run would have
      // merged markers into (#166).
      //
      // A directory standing where a file has to go is the one write
      // failure that fails the same way on all three CI platforms.
      Directory(p.join(project.path, 'lib', 'b.dart')).createSync();
      // lib/a.dart conflicts, which puts the write ordering under test
      // too: it must not have been marked when lib/b.dart failed.
      File(
        p.join(project.path, 'lib', 'a.dart'),
      ).writeAsStringSync('alpha local edit\n');

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.software.code, reason: log.toString());
      expect(log.toString(), contains('Could not write lib/b.dart'));
      expect(log.toString(), isNot(contains('Applied.')));
      final meta =
          jsonDecode(
                File(p.join(project.path, '.fluframe.json')).readAsStringSync(),
              )
              as Map<String, dynamic>;
      // Nothing is claimed, so the re-run merges the same BASE again and
      // picks up the files the loop never reached.
      expect(meta['cliVersion'], '0.1.0');
      expect(meta.containsKey('pendingUpgrade'), isFalse);
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        isNot(contains('<<<<<<<')),
        reason: 'a file left marked is what makes that re-merge destructive',
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

    test('a merge keeps the user edit and the upstream edit', () async {
      // Every other clean-merge case here has OURS byte-identical to BASE,
      // so git merge-file degenerates to "take theirs" and a plain
      // overwrite would satisfy them. Here the two sides edited different
      // regions of one file: both have to survive, unconflicted.
      const base =
          'header\n'
          'region a\n'
          'filler 1\n'
          'filler 2\n'
          'filler 3\n'
          'filler 4\n'
          'filler 5\n'
          'region b\n'
          'footer\n';
      writeFile(p.join(oldTemplates.path, 'app'), 'lib/wide.dart', base);
      writeFile(
        newTemplate.path,
        'lib/wide.dart',
        base.replaceAll('region b', 'region b, upstream'),
      );
      writeFile(
        project.path,
        'lib/wide.dart',
        base.replaceAll('region a', 'region a, yours'),
      );

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      final content = File(
        p.join(project.path, 'lib', 'wide.dart'),
      ).readAsStringSync();
      expect(content, contains('region a, yours'));
      expect(content, contains('region b, upstream'));
      expect(content, isNot(contains('<<<<<<<')));
      expect(log.toString(), contains('~ lib/wide.dart'));
    });

    test('a CRLF file keeps its line endings through a merge', () async {
      // Regression: everything is normalized to LF to compare, and the
      // merged result used to be written back that way — turning one
      // merged hunk into a whole-file diff on a Windows checkout.
      writeFile(
        p.join(oldTemplates.path, 'app'),
        'lib/crlf.dart',
        'one\ntwo\n',
      );
      writeFile(newTemplate.path, 'lib/crlf.dart', 'one\ntwo\nthree\n');
      writeFile(project.path, 'lib/crlf.dart', 'one\r\ntwo\r\n');

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(project.path, 'lib', 'crlf.dart')).readAsStringSync(),
        'one\r\ntwo\r\nthree\r\n',
      );
      // ...and an LF file is not converted the other way.
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
    });

    test('a file that is not UTF-8 is reported, not fatal', () async {
      // Regression: one undecodable file anywhere in the tree aborted the
      // entire run with an uncaught FormatException from readAsStringSync.
      const bytes = [0x89, 0x50, 0x4e, 0x47, 0xff, 0x0a];
      writeFile(p.join(oldTemplates.path, 'app'), 'lib/logo.png', 'stub\n');
      writeFile(newTemplate.path, 'lib/logo.png', 'stub\n');
      File(p.join(project.path, 'lib', 'logo.png')).writeAsBytesSync(bytes);

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(log.toString(), contains('? lib/logo.png'));
      expect(log.toString(), contains('not UTF-8 text'));
      // Left byte for byte as it was...
      expect(
        File(p.join(project.path, 'lib', 'logo.png')).readAsBytesSync(),
        bytes,
      );
      // ...and the rest of the upgrade still happened.
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
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

    /// Rewrites the fixture's metadata to record [backend].
    void recordBackend(String backend) {
      final meta = {
        'cliVersion': '0.1.0',
        'name': 'demo_app',
        'org': 'dev.example',
        'backend': backend,
      };
      writeFile(project.path, '.fluframe.json', '${jsonEncode(meta)}\n');
    }

    test('an addon this CLI no longer knows degrades the base', () async {
      // Regression: the merge base was rebuilt from the OLD bundle but
      // with the CURRENT CLI's addon anchors, and a missing anchor was a
      // hard stop — so every app generated with any addon became
      // permanently un-upgradable the moment the template moved a line.
      recordBackend('a-backend-from-the-future');

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(log.toString(), contains('rebuilt without'));
      // The upgrade still happened.
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
    });

    test('each bundle replays the addon anchors of its own era', () async {
      // The published bundle carries addons.json precisely so a future
      // CLI can rebuild the base with the anchors that matched the
      // template of that era. Here the old anchor ('alpha') does not
      // exist in the new template and vice versa, so reconstructing
      // either side with the wrong definitions fails outright.
      recordBackend('legacy');
      void writeRegistry(String root, String anchor, String replacement) {
        writeFile(
          root,
          addonRegistryFileName,
          jsonEncode({
            'schema': 1,
            'backends': {
              'legacy': BackendAddon(
                name: 'legacy',
                requiresFiles: false,
                dependencies: const [],
                patches: [
                  AddonPatch(
                    file: 'lib/a.dart',
                    anchor: anchor,
                    replacement: replacement,
                  ),
                ],
              ).toJson(),
            },
            'errorReporting': <String, Object?>{},
            'analytics': <String, Object?>{},
          }),
        );
      }

      writeRegistry(oldTemplates.path, 'alpha\n', 'alpha // legacy\n');
      writeRegistry(
        newTemplate.parent.path,
        'alpha v2\n',
        'alpha v2 // legacy\n',
      );
      // An app generated with the legacy addon carries its patch.
      writeFile(project.path, 'lib/a.dart', 'alpha // legacy\n');

      final code = await upgrader().run(
        projectDir: project,
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(log.toString(), isNot(contains('rebuilt without')));
      // Clean merge, with the current era's patch applied.
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2 // legacy\n',
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

    test('refuses a directory that is not a generated app', () async {
      // Regression: --from made any directory upgradable, so running this
      // one folder too high reported a full template as "added" — and
      // --apply would have unpacked it there.
      final stranger = Directory(p.join(temp.path, 'not_an_app'))..createSync();

      final code = await upgrader().run(
        projectDir: stranger,
        fromOverride: '0.1.0',
        apply: true,
        force: true,
      );

      expect(code, ExitCode.usage.code, reason: log.toString());
      expect(log.toString(), contains('does not look like a generated app'));
      expect(stranger.listSync(), isEmpty);
    });

    test('--from still upgrades a pre-0.14.0 app with no metadata', () async {
      // That refusal must not close the escape hatch it names: apps from
      // before 0.14.0 have a pubspec.yaml but no .fluframe.json.
      File(p.join(project.path, '.fluframe.json')).deleteSync();

      final code = await upgrader().run(
        projectDir: project,
        fromOverride: '0.1.0',
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(project.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
    });

    test('a recorded name that is not a package name is refused', () async {
      // .fluframe.json is written into every generated app and is not
      // gitignored, so this value is committed and travels with a cloned
      // repo. It is handed to ProjectGenerator as the directory the merge
      // base is rebuilt in, and package:path's join discards everything
      // before an absolute part — so an absolute name put a whole
      // template tree wherever it pointed. The rebuild runs before any
      // --apply check, which makes a plain `fluframe upgrade` enough.
      final escape = p.join(temp.path, 'pwned');
      for (final name in ['../../pwned', escape]) {
        final meta = {'cliVersion': '0.1.0', 'name': name};
        writeFile(project.path, '.fluframe.json', '${jsonEncode(meta)}\n');

        final code = await upgrader().run(projectDir: project);

        expect(code, ExitCode.data.code, reason: '$name → $log');
        expect(log.toString(), contains('.fluframe.json'), reason: name);
        expect(Directory(escape).existsSync(), isFalse, reason: name);
      }
    });

    test('a pendingConflicts entry that leaves the app is refused', () async {
      // The recorded paths are joined onto the project root to look for
      // conflict markers, so `..` or an absolute path aims that read at a
      // file the command has no business touching. Input hygiene, not a
      // leak: the helper returns a bool to the user's own terminal.
      for (final entry in ['../../.bashrc', r'..\..\.bashrc']) {
        final meta = {
          'cliVersion': '0.1.0',
          'name': 'demo_app',
          'pendingUpgrade': '1.9.9',
          'pendingConflicts': [entry],
        };
        writeFile(project.path, '.fluframe.json', '${jsonEncode(meta)}\n');

        final code = await upgrader().run(projectDir: project);

        expect(code, ExitCode.data.code, reason: '$entry → $log');
        expect(
          log.toString(),
          contains('not a path inside the app'),
          reason: entry,
        );
      }
    });

    test('--from reads the package name from the pubspec, not the '
        'folder', () async {
      // The guards above must not close #168's fallback chain: a monorepo
      // path or a renamed checkout is not a package name, and the
      // pubspec's own `name:` is what carries the run.
      final renamed = Directory(p.join(temp.path, 'my-app'))..createSync();
      writeFile(renamed.path, 'pubspec.yaml', 'name: demo_app\n');
      writeFile(renamed.path, 'lib/a.dart', 'alpha\n');

      final code = await upgrader().run(
        projectDir: renamed,
        fromOverride: '0.1.0',
        apply: true,
        force: true,
      );

      expect(code, ExitCode.success.code, reason: log.toString());
      expect(
        File(p.join(renamed.path, 'lib', 'a.dart')).readAsStringSync(),
        'alpha v2\n',
      );
    });

    test('a folder name that is not a package name is refused', () async {
      // Last resort in the same chain, and the one no validator has seen:
      // with no recorded name and no pubspec `name:`, the directory
      // basename is what reaches p.join.
      final renamed = Directory(p.join(temp.path, 'my-app'))..createSync();
      writeFile(renamed.path, 'pubspec.yaml', 'description: nameless\n');

      final code = await upgrader().run(
        projectDir: renamed,
        fromOverride: '0.1.0',
      );

      expect(code, ExitCode.data.code, reason: log.toString());
      expect(log.toString(), contains('my-app'));
    });

    test('a broken addons.json falls back instead of crashing', () async {
      // #187, third recurrence. _readAddonRegistry catches only
      // FormatException and promises to fall back to this version's
      // definitions, but each shape below met a bare `as` or `!` inside
      // the decoder and threw a TypeError — an Error, so the promise
      // could not be kept and a data problem in a DOWNLOADED bundle
      // reached the user as a fluframe crash with a stack trace.
      const broken = [
        // the registry itself is not an object
        '[]',
        // an addon entry is not an object
        '{"schema":1,"backends":{"l":5}}',
        // a patch with no "file" key
        '{"schema":1,"backends":{"l":{"name":"l","dependencies":[],'
            '"patches":[{"anchor":"a","replacement":"b"}]}}}',
        // a patch whose anchor is not a string
        '{"schema":1,"backends":{"l":{"name":"l","dependencies":[],'
            '"patches":[{"file":"lib/a.dart","anchor":5}]}}}',
        // "patches" is not a list
        '{"schema":1,"backends":{"l":{"name":"l","dependencies":[],'
            '"patches":"nope"}}}',
      ];

      for (final registry in broken) {
        writeFile(oldTemplates.path, addonRegistryFileName, registry);

        final code = await upgrader().run(projectDir: project);

        expect(code, ExitCode.success.code, reason: '$registry → $log');
        expect(log.toString(), contains('Falling back'), reason: registry);
      }
    });
  });
}
