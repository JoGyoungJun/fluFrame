import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fluframe/src/commands/doctor_command.dart';
import 'package:test/test.dart';

void main() {
  group('DoctorCommand', () {
    late StringBuffer out;

    // Stands in for the resolved bundle. Never read from, only printed:
    // what matters is that the tests stop asking the machine.
    const stubTemplate = '/stub/templates/app';

    CommandRunner<int> runnerWith(
      Future<ProcessResult> Function(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      })
      runProcess, {
      bool canCreateSymlink = true,
      String? dartConstraint = '^3.0.0',
      bool templateFound = true,
    }) {
      out = StringBuffer();
      return CommandRunner<int>('test', 'test')..addCommand(
        DoctorCommand(
          runProcess: runProcess,
          out: out,
          // Pinned so the suite is not at the mercy of whether the
          // machine running it has Developer Mode on.
          canCreateSymlink: () => canCreateSymlink,
          // Pinned for the same reason: production reads this out of the
          // resolved template's pubspec, and the suite must not go red the
          // day that constraint is bumped.
          dartConstraint: dartConstraint,
          // And pinned here too: production resolves this from the
          // activated package, so leaving it live made every test below
          // pass because of the repo checkout's layout rather than
          // because of anything it asserts — and left the fatal branch
          // for a missing bundle unreachable.
          resolveTemplate: () async =>
              templateFound ? Directory(stubTemplate) : null,
        ),
      );
    }

    Future<ProcessResult> allToolsPresent(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    }) async => ProcessResult(0, 0, '$executable 3.12.1\n', '');

    test('all tools present reports ok and exits 0', () async {
      final runner = runnerWith(allToolsPresent);

      final code = await runner.run(['doctor']);

      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[ok] flutter 3.12.1'));
      expect(out.toString(), contains('[ok] template bundle: $stubTemplate'));
      expect(out.toString(), contains('All set'));
    });

    test('a Dart below the template floor is fatal, not "All set"', () async {
      // Regression: doctor printed "All set" for any Dart it could run, so a
      // machine on an older stable channel was told it was fine and only
      // found out a minute into `create`, in a raw pub solver error.
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        return Future.value(ProcessResult(0, 0, '$executable 2.19.6\n', ''));
      });

      final code = await runner.run(['doctor']);

      final report = out.toString();
      expect(code, 69, reason: report);
      expect(report, contains('[!!] Dart 2.19.6'));
      expect(report, contains('^3.0.0'));
      expect(report, contains('flutter upgrade'));
      expect(report, isNot(contains('All set')));
    });

    test('a Dart past the next major is fatal too', () async {
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        return Future.value(ProcessResult(0, 0, '$executable 4.0.0\n', ''));
      });

      final code = await runner.run(['doctor']);

      expect(code, 69, reason: out.toString());
      expect(out.toString(), contains('[!!] Dart 4.0.0'));
      expect(out.toString(), isNot(contains('All set')));
    });

    test('an unbounded constraint skips the check, never fails it', () async {
      // `any` is a real pub constraint with no floor to check against, and
      // a constraint that cannot be bounded must not reject a machine that
      // would have worked. (Passing null here would mean "read it from the
      // template", which is the production path, not this one.)
      final runner = runnerWith(allToolsPresent, dartConstraint: 'any');

      final code = await runner.run(['doctor']);

      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('skipping that check'));
      expect(out.toString(), contains('All set'));
    });

    test('missing flutter is fatal with an install pointer', () async {
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        if (executable == 'flutter') {
          throw const ProcessException('flutter', ['--version']);
        }
        return Future.value(ProcessResult(0, 0, '$executable 3.12.1\n', ''));
      });

      final code = await runner.run(['doctor']);

      expect(code, 69);
      expect(out.toString(), contains('[!!] Flutter SDK not found'));
      expect(
        out.toString(),
        contains('https://docs.flutter.dev/get-started/install'),
      );
    });

    test('missing dart is fatal, not a warning', () async {
      // Dart ships inside Flutter, so a host with Flutter but no `dart` on
      // PATH is a PATH-ordering problem, not a missing install — and every
      // later step shells out to `dart`. Dropping the `fatal = true` on
      // this branch alone leaves doctor printing "[!!] Dart not found" and
      // then "All set", exit 0, with the whole suite still green.
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        if (executable == 'dart') {
          throw const ProcessException('dart', ['--version']);
        }
        return Future.value(ProcessResult(0, 0, '$executable 3.12.1\n', ''));
      });

      final code = await runner.run(['doctor']);

      expect(code, 69);
      expect(out.toString(), contains('[!!] Dart not found on PATH'));
      expect(out.toString(), isNot(contains('All set')));
    });

    test('missing git is a warning, not a failure', () async {
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        if (executable == 'git') {
          return Future.value(ProcessResult(0, 127, '', 'not found'));
        }
        return Future.value(ProcessResult(0, 0, '$executable 3.12.1\n', ''));
      });

      final code = await runner.run(['doctor']);

      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[--] git not found'));
    });

    test('no symlink support is fatal, before "All set" is printed', () async {
      // Regression: doctor declared "All set", then `create` spent a minute
      // scaffolding and died in `flutter pub get` because the default
      // platforms include windows/linux, whose plugins need symlinks.
      final runner = runnerWith(allToolsPresent, canCreateSymlink: false);

      final code = await runner.run(['doctor']);

      expect(code, 69, reason: out.toString());
      final report = out.toString();
      expect(report, contains('[!!] Symbolic links are unavailable'));
      expect(report, contains('--platforms=android,ios,web'));
      expect(report, isNot(contains('All set')));
      if (Platform.isWindows) {
        expect(report, contains('ms-settings:developers'));
      }
    });

    test('a missing template bundle is fatal, not "All set"', () async {
      // Nothing could reach this branch before resolveTemplate became a
      // seam. It fires on a broken `dart pub global activate` — the exact
      // install `fluframe doctor` exists to diagnose — so had it ever
      // regressed to non-fatal, a user whose CLI cannot generate anything
      // would have been told "All set. Try: fluframe create my_app".
      final runner = runnerWith(allToolsPresent, templateFound: false);

      final code = await runner.run(['doctor']);

      final report = out.toString();
      expect(code, 69, reason: report);
      expect(report, contains('[!!] fluFrame template bundle not found'));
      expect(report, contains('dart pub global activate fluframe'));
      expect(report, isNot(contains('All set')));
    });

    test('symlink support is reported as a passing check', () async {
      final runner = runnerWith(allToolsPresent);

      final code = await runner.run(['doctor']);

      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[ok] symbolic links available'));
    });

    test(
      'a tool that exits 0 printing nothing is reported as missing',
      () async {
        // `''.split('\n')` is `['']`, so an empty trimmed stdout used to
        // come back as the empty string rather than null: `run()` printed a
        // bare `[ok] ` with no version, and the SDK-floor check silently
        // degraded to `unknown` while the report still ended "All set".
        // A shim that writes `--version` to stderr does exactly this.
        final runner = runnerWith((executable, arguments, {workingDirectory}) {
          if (executable == 'flutter') {
            return Future.value(ProcessResult(0, 0, '   \n', ''));
          }
          return allToolsPresent(
            executable,
            arguments,
            workingDirectory: workingDirectory,
          );
        });

        final code = await runner.run(['doctor']);

        final report = out.toString();
        expect(code, 69, reason: report);
        expect(report, contains('[!!] Flutter SDK not found on PATH.'));
        expect(report, isNot(contains('[ok] \n')));
        expect(report, isNot(contains('All set')));
      },
    );

    group('the production SDK-floor path', () {
      // Every other test in this file injects `dartConstraint`, which is
      // the LEFT operand of `dartConstraint ?? _constraintOf(template)`.
      // That leaves the production path — locate pubspec.yaml under the
      // resolved bundle and read its `environment: sdk:` — driven by
      // nothing. If that join breaks, the floor check reports `unknown`,
      // prints "skipping that check", and still ends "All set": the exact
      // silent pass the check was added to stop.
      late Directory templateDir;

      setUp(() {
        templateDir = Directory.systemTemp.createTempSync('fluframe_doctor_');
      });

      tearDown(() {
        if (templateDir.existsSync()) templateDir.deleteSync(recursive: true);
      });

      CommandRunner<int> runnerReadingTemplate() {
        out = StringBuffer();
        return CommandRunner<int>('test', 'test')..addCommand(
          DoctorCommand(
            runProcess: allToolsPresent,
            out: out,
            canCreateSymlink: () => true,
            // dartConstraint is deliberately NOT passed. Leaving it at its
            // default of null is what selects the production path — read
            // the floor out of the resolved bundle's own pubspec — which
            // every other test in this file overrides away.
            resolveTemplate: () async => templateDir,
          ),
        );
      }

      test('reads the constraint out of the resolved bundle pubspec', () async {
        File('${templateDir.path}/pubspec.yaml').writeAsStringSync(
          'name: fluframe_app\n'
          'environment:\n'
          '  sdk: ^3.99.0\n',
        );

        final code = await runnerReadingTemplate().run(['doctor']);

        final report = out.toString();
        // allToolsPresent reports Dart 3.12.1, which cannot satisfy ^3.99.0.
        expect(code, 69, reason: report);
        expect(report, contains('^3.99.0'));
        expect(report, isNot(contains('skipping that check')));
        expect(report, isNot(contains('All set')));
      });

      test(
        'a bundle with no pubspec degrades to a stated skip, not a throw',
        () async {
          final code = await runnerReadingTemplate().run(['doctor']);

          final report = out.toString();
          expect(code, 0, reason: report);
          expect(report, contains('skipping that check'));
        },
      );
    });
  });
}
