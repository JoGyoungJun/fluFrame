import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:fluframe/src/commands/create_command.dart';
import 'package:fluframe/src/commands/doctor_command.dart';
import 'package:fluframe/src/commands/upgrade_command.dart';
import 'package:fluframe/src/version.dart';
import 'package:io/io.dart';

export 'package:fluframe/src/version.dart';

/// Where to file a report when fluframe itself is at fault.
const _issueTracker = 'https://github.com/JoGyoungJun/fluFrame/issues';

/// Entry point of the `fluframe` command line interface.
class FluframeCommandRunner extends CommandRunner<int> {
  /// Creates the runner and registers all subcommands.
  ///
  /// [err] receives usage and failure reports; injectable for tests.
  FluframeCommandRunner({StringSink? err})
    : _err = err ?? io.stderr,
      super(
        'fluframe',
        'Generate production-ready Flutter apps from the fluFrame '
            'boilerplate.',
      ) {
    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Print the fluframe version.',
    );
    addCommand(CreateCommand());
    addCommand(DoctorCommand());
    addCommand(UpgradeCommand());
  }

  final StringSink _err;

  /// Runs [args] and returns the process exit code.
  ///
  /// Every failure is turned into a sentence and a
  /// [sysexits](https://man.freebsd.org/cgi/man.cgi?sysexits) code here.
  /// Anything left to escape reaches `main` as an unhandled asynchronous
  /// error, which prints a raw trace and exits -1 — unreadable, and not a
  /// code a script can branch on.
  @override
  Future<int> run(Iterable<String> args) async {
    try {
      final results = parse(args);
      if (results['version'] == true) {
        io.stdout.writeln('fluframe $cliVersion');
        return ExitCode.success.code;
      }
      return await runCommand(results) ?? ExitCode.success.code;
    } on UsageException catch (exception) {
      _err.writeln(exception);
      return ExitCode.usage.code;
    } on BundleException catch (exception) {
      _err.writeln(exception.message);
      final hint = exception.hint;
      if (hint != null) _err.writeln(hint);
      return ExitCode.unavailable.code;
    } on FormatException catch (exception) {
      // The default toString() reprints the offending source with a caret
      // under it — six lines of a JSON file to say one thing. The file is
      // named here because .fluframe.json is the only JSON the CLI reads
      // that a user writes; everything else wraps its own decode errors.
      final at = exception.offset == null
          ? ''
          : ' (at offset ${exception.offset})';
      _err
        ..writeln('Malformed JSON$at: ${exception.message}')
        ..writeln(
          'This is almost always .fluframe.json in the app being '
          'upgraded. Fix it, or delete it and re-run with '
          '--from <the fluframe version the app was generated with>.',
        );
      return ExitCode.data.code;
    } on Object catch (error, stackTrace) {
      // Unrecognised: say what happened first, so the top line is readable
      // even when the trace scrolls past, then keep the trace so the bug
      // stays reportable.
      _err
        ..writeln('fluframe failed with an unexpected error: $error')
        ..writeln('This is a bug. Please report it, with the trace below:')
        ..writeln(_issueTracker)
        ..writeln(stackTrace);
      return ExitCode.software.code;
    }
  }
}
