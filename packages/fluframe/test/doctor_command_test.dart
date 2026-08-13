import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fluframe/src/commands/doctor_command.dart';
import 'package:test/test.dart';

void main() {
  group('DoctorCommand', () {
    late StringBuffer out;

    CommandRunner<int> runnerWith(
      Future<ProcessResult> Function(
        String executable,
        List<String> arguments, {
        String? workingDirectory,
      })
      runProcess, {
      bool canCreateSymlink = true,
      String? dartConstraint = '^3.0.0',
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

      // The template resolves from the repo checkout in tests.
      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[ok] flutter 3.12.1'));
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

    test('symlink support is reported as a passing check', () async {
      final runner = runnerWith(allToolsPresent);

      final code = await runner.run(['doctor']);

      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[ok] symbolic links available'));
    });
  });
}
