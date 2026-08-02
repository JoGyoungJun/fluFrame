import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:io/io.dart';

/// `fluframe create <project_name>` — scaffolds a new app from the template.
class CreateCommand extends Command<int> {
  /// Creates the command and registers its options.
  CreateCommand() {
    argParser
      ..addOption(
        'org',
        defaultsTo: 'com.example',
        help: 'Organization used for bundle/application identifiers.',
      )
      ..addOption(
        'description',
        help: 'Description written into the new pubspec.yaml.',
      )
      ..addOption(
        'output-directory',
        abbr: 'o',
        defaultsTo: '.',
        help: 'Directory the project folder is created in.',
      )
      ..addMultiOption(
        'platforms',
        defaultsTo: ['android', 'ios', 'web', 'windows', 'macos', 'linux'],
        help: 'Platforms passed through to flutter create.',
      )
      ..addOption(
        'template-dir',
        hide: true,
        help: 'Override the template location (development only).',
      )
      ..addFlag(
        'pub',
        defaultsTo: true,
        help: 'Run flutter pub get and gen-l10n after generating.',
      );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create a new Flutter app from the fluFrame boilerplate.';

  @override
  String get invocation => 'fluframe create <project_name> [arguments]';

  @override
  Future<int> run() async {
    final results = argResults!;
    if (results.rest.length != 1) {
      usageException('Specify exactly one project name.');
    }
    final projectName = results.rest.first;
    if (!isValidPackageName(projectName)) {
      usageException(
        '"$projectName" is not a valid Dart package name '
        '(lower_snake_case, no leading digit, not a reserved word).',
      );
    }

    final templateDirectory = await resolveTemplateDirectory(
      explicitPath: results['template-dir'] as String?,
    );
    if (templateDirectory == null) {
      io.stderr.writeln(
        'Could not locate the fluFrame template. '
        'Reinstall with: dart pub global activate fluframe',
      );
      return ExitCode.software.code;
    }

    final generator = ProjectGenerator(templateDirectory: templateDirectory);
    return generator.generate(
      name: projectName,
      org: results['org'] as String,
      description: results['description'] as String?,
      outputDirectory: results['output-directory'] as String,
      platforms: results['platforms'] as List<String>,
      runPub: results['pub'] as bool,
    );
  }
}
