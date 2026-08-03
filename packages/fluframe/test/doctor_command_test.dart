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
      runProcess,
    ) {
      out = StringBuffer();
      return CommandRunner<int>('test', 'test')
        ..addCommand(DoctorCommand(runProcess: runProcess, out: out));
    }

    test('all tools present reports ok and exits 0', () async {
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        return Future.value(ProcessResult(0, 0, '$executable 1.0.0\n', ''));
      });

      final code = await runner.run(['doctor']);

      // The template resolves from the repo checkout in tests.
      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[ok] flutter 1.0.0'));
      expect(out.toString(), contains('All set'));
    });

    test('missing flutter is fatal with an install pointer', () async {
      final runner = runnerWith((executable, arguments, {workingDirectory}) {
        if (executable == 'flutter') {
          throw const ProcessException('flutter', ['--version']);
        }
        return Future.value(ProcessResult(0, 0, '$executable 1.0.0\n', ''));
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
        return Future.value(ProcessResult(0, 0, '$executable 1.0.0\n', ''));
      });

      final code = await runner.run(['doctor']);

      expect(code, 0, reason: out.toString());
      expect(out.toString(), contains('[--] git not found'));
    });
  });
}
