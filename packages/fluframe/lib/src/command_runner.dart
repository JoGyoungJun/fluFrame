import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/commands/create_command.dart';
import 'package:fluframe/src/commands/doctor_command.dart';
import 'package:io/io.dart';

/// The current version of the fluframe CLI. Keep in sync with pubspec.yaml.
const String cliVersion = '0.10.0';

/// Entry point of the `fluframe` command line interface.
class FluframeCommandRunner extends CommandRunner<int> {
  /// Creates the runner and registers all subcommands.
  FluframeCommandRunner()
    : super(
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
  }

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
      io.stderr.writeln(exception);
      return ExitCode.usage.code;
    }
  }
}
