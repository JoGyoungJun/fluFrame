import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:fluframe/src/process_runner.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:io/io.dart';

/// `fluframe create <project_name>` — scaffolds a new app from the template.
class CreateCommand extends Command<int> {
  /// Creates the command and registers its options.
  ///
  /// [makeGenerator] is injectable for tests, as `makeUpgrader` is on
  /// `UpgradeCommand` and `makeScaffold` on `AddFeatureCommand`: it
  /// receives the resolved template directory and returns the generator
  /// [run] drives, so the nine values parsed below can be checked where
  /// they are parsed rather than only where they are already named Dart
  /// arguments.
  CreateCommand({
    ProjectGenerator Function(io.Directory templateDirectory)? makeGenerator,
  }) : _makeGenerator = makeGenerator ?? _defaultGenerator {
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
        defaultsTo: defaultPlatforms,
        allowed: defaultPlatforms,
        help: 'Platforms passed through to flutter create.',
      )
      ..addOption(
        'backend',
        defaultsTo: 'none',
        allowed: ['none', ...backendAddons.keys],
        help: 'Wire a real auth backend into the generated app.',
      )
      ..addOption(
        'error-reporting',
        defaultsTo: 'none',
        allowed: ['none', ...errorReportingAddons.keys],
        help: 'Wire a crash-reporting service into the error hooks.',
      )
      ..addOption(
        'analytics',
        defaultsTo: 'none',
        allowed: ['none', ...analyticsAddons.keys],
        help: 'Wire a product-analytics service into the analytics seam.',
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

  final ProjectGenerator Function(io.Directory templateDirectory)
  _makeGenerator;

  /// The generator the command runs with when nothing was injected.
  static ProjectGenerator _defaultGenerator(io.Directory templateDirectory) =>
      ProjectGenerator(templateDirectory: templateDirectory);

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
    final rejection = packageNameRejection(projectName);
    if (rejection != null) {
      usageException('Cannot create "$projectName": $rejection.');
    }
    final org = results['org'] as String;
    if (!isValidOrg(org)) {
      usageException(
        '"$org" is not a valid organization identifier '
        '(dot-separated segments, each starting with a letter, '
        'e.g. com.example).',
      );
    }

    final outputDirectory = results['output-directory'] as String;
    // The one create argument that reached `flutter create`
    // unvalidated: the name and the org above are both checked, while
    // on Windows cmd.exe splits the command line at a metacharacter
    // before flutter ever sees it — see shellArgumentRejection.
    final outputRejection = shellArgumentRejection(outputDirectory);
    if (outputRejection != null) {
      usageException(
        'Cannot create "$projectName" in "$outputDirectory": '
        'the path $outputRejection.',
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

    final backend = results['backend'] as String;
    final errorReporting = results['error-reporting'] as String;
    final analytics = results['analytics'] as String;
    final generator = _makeGenerator(templateDirectory);
    return generator.generate(
      name: projectName,
      org: org,
      description: results['description'] as String?,
      backend: backend == 'none' ? null : backend,
      errorReporting: errorReporting == 'none' ? null : errorReporting,
      analytics: analytics == 'none' ? null : analytics,
      outputDirectory: outputDirectory,
      platforms: results['platforms'] as List<String>,
      runPub: results['pub'] as bool,
    );
  }
}
