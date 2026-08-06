import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:fluframe/src/upgrader.dart';
import 'package:io/io.dart';

/// `fluframe upgrade` — apply template updates to a generated app via a
/// three-way merge (design spec 002, ADR 0002). Dry-run by default.
class UpgradeCommand extends Command<int> {
  /// Creates the command and registers its options.
  UpgradeCommand() {
    argParser
      ..addFlag(
        'apply',
        negatable: false,
        help: 'Write the merged results (default is a dry-run report).',
      )
      ..addFlag(
        'force',
        negatable: false,
        help:
            'Apply even when the app is not a clean git working tree '
            '(--apply keeps no backup, so there would be no way back).',
      )
      ..addOption(
        'from',
        help:
            'fluframe version the app was generated with (only needed '
            'for apps created before 0.14.0, which lack .fluframe.json).',
      )
      ..addOption(
        'project-dir',
        defaultsTo: '.',
        help: 'Root of the generated app to upgrade.',
      );
  }

  @override
  String get name => 'upgrade';

  @override
  String get description =>
      'Apply template updates to an existing generated app '
      '(three-way merge; dry-run by default).';

  @override
  Future<int> run() async {
    final results = argResults!;
    final templateDirectory = await resolveTemplateDirectory();
    if (templateDirectory == null) {
      io.stderr.writeln(
        'Could not locate the fluFrame template. '
        'Reinstall with: dart pub global activate fluframe',
      );
      return ExitCode.software.code;
    }
    final upgrader = Upgrader(currentTemplate: templateDirectory);
    return upgrader.run(
      projectDir: io.Directory(results['project-dir'] as String),
      fromOverride: results['from'] as String?,
      apply: results['apply'] as bool,
      force: results['force'] as bool,
    );
  }
}
