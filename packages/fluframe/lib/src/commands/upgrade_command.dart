import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:fluframe/src/upgrader.dart';
import 'package:io/io.dart';

/// `fluframe upgrade` — apply template updates to a generated app via a
/// three-way merge (design spec 002, ADR 0002). Dry-run by default.
class UpgradeCommand extends Command<int> {
  /// Creates the command and registers its options.
  ///
  /// [makeUpgrader] is injectable for tests: it receives the resolved
  /// template directory and returns the upgrader [run] drives, so the
  /// five options below can be checked where they are parsed rather than
  /// only where they are already named Dart arguments.
  UpgradeCommand({
    Upgrader Function(io.Directory currentTemplate)? makeUpgrader,
  }) : _makeUpgrader = makeUpgrader ?? _defaultUpgrader {
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
      ..addFlag(
        'restore-deleted',
        negatable: false,
        help:
            'Bring back template files you deleted or renamed (they are '
            'reported but left alone by default).',
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

  final Upgrader Function(io.Directory currentTemplate) _makeUpgrader;

  /// The upgrader the command runs with when nothing was injected.
  static Upgrader _defaultUpgrader(io.Directory currentTemplate) =>
      Upgrader(currentTemplate: currentTemplate);

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
    final upgrader = _makeUpgrader(templateDirectory);
    return upgrader.run(
      projectDir: io.Directory(results['project-dir'] as String),
      fromOverride: results['from'] as String?,
      apply: results['apply'] as bool,
      force: results['force'] as bool,
      restoreDeleted: results['restore-deleted'] as bool,
    );
  }
}
