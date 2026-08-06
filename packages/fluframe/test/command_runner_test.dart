import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:fluframe/src/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A command that fails on demand, so the runner's top-level handling can
/// be exercised without the network or disk a real failure would need.
class _FailingCommand extends Command<int> {
  _FailingCommand(this._failure);

  final Object _failure;

  @override
  String get name => 'boom';

  @override
  String get description => 'Fails, for tests.';

  // The trace is passed along explicitly: a Future.error without one
  // arrives at the handler with an empty StackTrace, which no real throw
  // ever does.
  @override
  Future<int> run() => Future<int>.error(_failure, StackTrace.current);
}

void main() {
  group('FluframeCommandRunner', () {
    test('--version exits successfully', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['--version']), 0);
    });

    test('create without a project name is a usage error', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['create']), 64);
    });

    test('create rejects an invalid project name', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['create', 'BadName']), 64);
    });

    test('create rejects names that would break generation', () async {
      final runner = FluframeCommandRunner();

      // Each of these used to be accepted, and generation then failed
      // after writing the whole project.
      expect(await runner.run(['create', 'dio']), 64);
      expect(await runner.run(['create', 'shared_preferences']), 64);
      expect(await runner.run(['create', 'firebase_core']), 64);
      expect(await runner.run(['create', 'con']), 64);
      expect(await runner.run(['create', '_private']), 64);
    });

    test('create rejects an invalid --org before running anything', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['create', 'my_app', '--org', 'bad org']), 64);
      expect(await runner.run(['create', 'my_app', '--org', '1com.x']), 64);
    });

    test('unknown commands are usage errors', () async {
      final runner = FluframeCommandRunner();

      expect(await runner.run(['nope']), 64);
    });

    test('a malformed .fluframe.json is reported, not dumped', () async {
      // This used to escape jsonDecode as an uncaught FormatException:
      // six lines of the file with a caret under it, and exit -1.
      final project = Directory.systemTemp.createTempSync('fluframe_meta_');
      addTearDown(() => project.deleteSync(recursive: true));
      File(p.join(project.path, '.fluframe.json'))
        ..createSync()
        ..writeAsStringSync('{"cliVersion": ');
      final err = StringBuffer();
      final runner = FluframeCommandRunner(err: err);

      final code = await runner.run([
        'upgrade',
        '--project-dir',
        project.path,
      ]);

      // 65 = EX_DATAERR: the input was bad, not the program.
      expect(code, 65, reason: err.toString());
      expect(err.toString(), contains('.fluframe.json'));
      expect(err.toString(), isNot(contains('#0')));
    });

    test('an unpublished version names the version that was asked '
        'for', () async {
      // The wording belongs to bundle_archive, which is where the pub.dev
      // 404 is turned into this; what is checked here is that the runner
      // relays it instead of letting an HttpException escape as a trace.
      final err = StringBuffer();
      final runner = FluframeCommandRunner(err: err)
        ..addCommand(
          _FailingCommand(
            BundleException(
              '0.14.0',
              'pub.dev has no published fluframe 0.14.0.',
              hint: 'See https://pub.dev/packages/fluframe/versions',
            ),
          ),
        );

      final code = await runner.run(['boom']);

      // 69 = EX_UNAVAILABLE: the bundle we depend on is not there.
      expect(code, 69, reason: err.toString());
      expect(err.toString(), contains('fluframe 0.14.0'));
      expect(err.toString(), contains('pub.dev/packages/fluframe/versions'));
      expect(err.toString(), isNot(contains('#0')));
    });

    test('an unexpected failure keeps its stack trace reportable', () async {
      final err = StringBuffer();
      final runner = FluframeCommandRunner(err: err)
        ..addCommand(_FailingCommand(StateError('impossible')));

      final code = await runner.run(['boom']);

      // 70 = EX_SOFTWARE: our fault. Message first, then the trace.
      expect(code, 70, reason: err.toString());
      expect(err.toString(), contains('impossible'));
      expect(err.toString(), contains('github.com/JoGyoungJun/fluFrame'));
      expect(err.toString(), contains('#0'));
    });
  });
}
