import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:fluframe/src/command_runner.dart';
import 'package:fluframe/src/commands/add_command.dart';
import 'package:fluframe/src/commands/upgrade_command.dart';
import 'package:fluframe/src/feature_scaffold.dart';
import 'package:fluframe/src/upgrader.dart';
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

/// A scaffold that plans cleanly and then fails the way `apply` does when
/// a write dies partway and the rollback cannot put every file back — the
/// one failure that leaves the app edited and not compiling.
class _UnrestorableScaffold extends FeatureScaffold {
  _UnrestorableScaffold({required super.projectDir});

  @override
  FeaturePlan plan({required String name, required bool tab}) =>
      const FeaturePlan(
        files: [],
        routerContents: '',
        arbContents: {},
        untranslated: {},
      );

  @override
  void apply(FeaturePlan plan, {required String name}) =>
      throw const FeatureScaffoldException(
        'Adding "billing" failed, and these files could not be put back: '
        'lib/l10n/app_ko.arb. Restore them (git checkout) before building.',
      );
}

/// A scaffold that plans cleanly and records whether `apply` was reached,
/// which is the one thing `--dry-run` must never do.
class _RecordingScaffold extends FeatureScaffold {
  _RecordingScaffold({required super.projectDir});

  /// Whether [apply] ran. A dry run leaves this false.
  bool applied = false;

  @override
  FeaturePlan plan({required String name, required bool tab}) =>
      const FeaturePlan(
        files: [PlannedFile('lib/features/user_reports/x.dart', '')],
        routerContents: '',
        arbContents: {'lib/l10n/app_en.arb': '{}'},
        untranslated: {},
      );

  @override
  void apply(FeaturePlan plan, {required String name}) {
    applied = true;
  }
}

/// An [Upgrader] that records what it was called with and merges
/// nothing.
///
/// The command reads five options out of the parser and hands them to
/// `Upgrader.run`; every other upgrader test calls that method with
/// named Dart arguments, so nothing crossed the parser. `apply` and
/// `force` are both read `as bool` there, which makes swapping the two
/// wires a change that compiles and type-checks.
class _RecordingUpgrader extends Upgrader {
  _RecordingUpgrader({required super.currentTemplate});

  /// What [run] was handed, or null until it is called.
  Directory? projectDir;

  /// The `--from` value, which stays null when the option is absent.
  String? fromOverride;

  /// The three flags, each null until [run] is called.
  bool? apply;
  bool? force;
  bool? restoreDeleted;

  @override
  Future<int> run({
    required Directory projectDir,
    String? fromOverride,
    bool apply = false,
    bool force = false,
    bool restoreDeleted = false,
  }) async {
    this.projectDir = projectDir;
    this.fromOverride = fromOverride;
    this.apply = apply;
    this.force = force;
    this.restoreDeleted = restoreDeleted;
    return 0;
  }
}

/// A [Stdout] that keeps what was written to it.
///
/// `add feature` prints its report straight to `io.stdout`, and
/// [IOOverrides.runZoned] is what makes that readable from a test —
/// without handing the command an output sink only a test would ever
/// pass.
class _CapturingStdout implements Stdout {
  _CapturingStdout(this._buffer);

  final StringBuffer _buffer;

  @override
  void writeln([Object? object = '']) => _buffer.writeln(object);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // The report only ever calls writeln. Anything else arriving here is
    // a change in how the command prints, and should say so instead of
    // being swallowed into an assertion that then reads empty.
    throw UnsupportedError(
      'This fake captures writeln only, not ${invocation.memberName}.',
    );
  }
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

    test('a feature that fails mid-apply keeps its rescue instruction '
        'readable', () async {
      // `apply` was called outside the try that catches
      // FeatureScaffoldException, so the one line telling the user which
      // files to restore arrived under "This is a bug. Please report it"
      // with a stack trace after it — at the exact moment the app is
      // edited and does not compile.
      final err = StringBuffer();
      final runner = FluframeCommandRunner(err: err)
        ..addCommand(
          AddFeatureCommand(
            err: err,
            makeScaffold: (projectDir) =>
                _UnrestorableScaffold(projectDir: projectDir),
          ),
        );

      final code = await runner.run(['feature', 'billing']);

      // 74 = EX_IOERR: the write failed. Not 64, which would blame the
      // invocation, and not the crash handler's 70.
      expect(code, 74, reason: err.toString());
      expect(err.toString(), contains('could not be put back'));
      expect(err.toString(), contains('git checkout'));
      expect(err.toString(), isNot(contains('This is a bug')));
      expect(err.toString(), isNot(contains('#0')));
    });

    test('--dry-run reports the plan and writes nothing', () async {
      // Nothing asserted that the flag ever reaches apply(): inverted, it
      // would scaffold the whole feature and edit the router while the
      // unit suite stayed green. The printed keys are checked here too —
      // the report once promised `user_reportsTitle` while
      // `userReportsTitle` was what landed in the ARBs (#183).
      final scaffold = _RecordingScaffold(projectDir: Directory.current);
      final runner = CommandRunner<int>('test', 'test')
        ..addCommand(AddFeatureCommand(makeScaffold: (_) => scaffold));
      final report = StringBuffer();

      final code = await IOOverrides.runZoned(
        () => runner.run(['feature', 'user_reports', '--dry-run']),
        stdout: () => _CapturingStdout(report),
      );

      expect(code, 0, reason: report.toString());
      expect(scaffold.applied, isFalse, reason: report.toString());
      expect(report.toString(), contains('Dry run'));
      expect(report.toString(), contains('userReportsTitle'));
      expect(report.toString(), isNot(contains('user_reportsTitle')));
    });

    test('without --dry-run the feature is applied', () async {
      // The other half of the flag. On its own, the test above stays
      // green for a command that ignores --dry-run and never writes at
      // all, which would be a different bug with the same symptom.
      final scaffold = _RecordingScaffold(projectDir: Directory.current);
      final runner = CommandRunner<int>('test', 'test')
        ..addCommand(AddFeatureCommand(makeScaffold: (_) => scaffold));
      final report = StringBuffer();

      final code = await IOOverrides.runZoned(
        () => runner.run(['feature', 'user_reports']),
        stdout: () => _CapturingStdout(report),
      );

      expect(code, 0, reason: report.toString());
      expect(scaffold.applied, isTrue, reason: report.toString());
      expect(report.toString(), contains('Created:'));
    });

    test('upgrade parses each option onto its own parameter', () async {
      // Of the five options the command registers, only --project-dir
      // had ever reached the parser from a test: the upgrader's own
      // tests call Upgrader.run with named Dart arguments, which cannot
      // see the wiring in between. The wiring is correct — this pins it.
      // `apply` and `force` are both read `as bool`, so swapping those
      // two compiles and type-checks: --apply would run as apply: false,
      // force: true, and --force alone as apply: true, force: false —
      // writing the merge over the working tree with the git-clean gate
      // skipped, and --apply keeps no backup to undo it with.
      final project = Directory.systemTemp.createTempSync('fluframe_opts_');
      addTearDown(() => project.deleteSync(recursive: true));
      // The double ignores its template root; the command still resolves
      // the real one and hands it to the seam.
      final template = Directory.current;

      Future<_RecordingUpgrader> upgradeWith(List<String> options) async {
        final upgrader = _RecordingUpgrader(currentTemplate: template);
        final runner = CommandRunner<int>('test', 'test')
          ..addCommand(UpgradeCommand(makeUpgrader: (_) => upgrader));
        final code = await runner.run([
          'upgrade',
          ...options,
          '--project-dir',
          project.path,
        ]);
        expect(code, 0, reason: 'upgrade $options did not run');
        return upgrader;
      }

      final everything = await upgradeWith([
        '--apply',
        '--force',
        '--restore-deleted',
        '--from',
        '1.2.3',
      ]);

      expect(everything.projectDir?.path, project.path);
      expect(everything.fromOverride, '1.2.3');
      expect(everything.apply, isTrue);
      expect(everything.force, isTrue);
      expect(everything.restoreDeleted, isTrue);

      // One flag at a time, which is the half that can see a crossed
      // wire: with all three set at once, two of them swapped record the
      // same three `true`s and everything above still passes.
      final applyOnly = await upgradeWith(['--apply']);
      expect(applyOnly.apply, isTrue);
      expect(applyOnly.force, isFalse);
      expect(applyOnly.restoreDeleted, isFalse);
      // Absent, not defaulted: --from is what pins an app too old to
      // carry .fluframe.json to a version, and a value invented here
      // would rebuild the merge base from the wrong template.
      expect(applyOnly.fromOverride, isNull);

      final forceOnly = await upgradeWith(['--force']);
      expect(forceOnly.apply, isFalse);
      expect(forceOnly.force, isTrue);
      expect(forceOnly.restoreDeleted, isFalse);

      final restoreOnly = await upgradeWith(['--restore-deleted']);
      expect(restoreOnly.apply, isFalse);
      expect(restoreOnly.force, isFalse);
      expect(restoreOnly.restoreDeleted, isTrue);
    });
  });
}
