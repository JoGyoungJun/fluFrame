import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/feature_scaffold.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:io/io.dart';

/// `fluframe add` — the parent of `fluframe add feature`.
class AddCommand extends Command<int> {
  /// Creates the command and registers its subcommands.
  AddCommand() {
    addSubcommand(AddFeatureCommand());
  }

  @override
  String get name => 'add';

  @override
  String get description => 'Add scaffolding to an existing generated app.';
}

/// `fluframe add feature <name>` — scaffold a feature module into an
/// existing app (design spec 003).
class AddFeatureCommand extends Command<int> {
  /// Creates the command and registers its options.
  AddFeatureCommand() {
    argParser
      ..addFlag(
        'tab',
        negatable: false,
        help: 'Also register the feature as a bottom-navigation tab.',
      )
      ..addFlag(
        'dry-run',
        negatable: false,
        help:
            'Print what would be created and changed, and write nothing. '
            'Unlike `fluframe upgrade`, this command writes by default: it '
            'only adds new files and three bounded insertions.',
      )
      ..addOption(
        'project-dir',
        defaultsTo: '.',
        help: 'Root of the generated app to add the feature to.',
      );
  }

  @override
  String get name => 'feature';

  @override
  String get description =>
      'Scaffold a feature module (repository, controller, screen, tests) '
      'and register its route.';

  @override
  String get invocation => 'fluframe add feature <name> [arguments]';

  @override
  Future<int> run() async {
    final results = argResults!;
    final rest = results.rest;
    if (rest.length != 1) {
      throw UsageException(
        rest.isEmpty
            ? 'Missing feature name.'
            : 'Expected exactly one feature name, got ${rest.length}.',
        usage,
      );
    }
    final name = rest.single;
    final tab = results['tab'] as bool;
    final dryRun = results['dry-run'] as bool;
    final projectDir = io.Directory(results['project-dir'] as String);

    final scaffold = FeatureScaffold(projectDir: projectDir);
    final FeaturePlan plan;
    try {
      plan = scaffold.plan(name: name, tab: tab);
    } on FeatureScaffoldException catch (exception) {
      io.stderr.writeln(exception.message);
      final hint = exception.hint;
      if (hint != null) io.stderr.writeln(hint);
      return ExitCode.usage.code;
    }

    if (dryRun) {
      _reportPlan(plan, name: name, tab: tab);
      return ExitCode.success.code;
    }

    scaffold.apply(plan, name: name);
    _reportApplied(plan, name: name, tab: tab);
    return ExitCode.success.code;
  }

  void _reportPlan(
    FeaturePlan plan, {
    required String name,
    required bool tab,
  }) {
    io.stdout.writeln('Dry run — nothing was written.\n');
    io.stdout.writeln('Would create:');
    for (final file in plan.files) {
      io.stdout.writeln('  ${file.path}');
    }
    io.stdout
      ..writeln('\nWould edit:')
      ..writeln(
        '  $routerPath (route${tab ? ', tab branch, destination' : ''})',
      );
    // The same camelCase keys the scaffold actually writes — printing the
    // raw name promised `user_reportsTitle` while `userReportsTitle` was
    // what landed in the ARBs (#183).
    final key = lowerCamelCase(name);
    for (final path in plan.arbContents.keys) {
      io.stdout.writeln('  $path (${key}Title${tab ? ', ${key}Tab' : ''})');
    }
    io.stdout.writeln('\nRe-run without --dry-run to apply.');
  }

  void _reportApplied(
    FeaturePlan plan, {
    required String name,
    required bool tab,
  }) {
    io.stdout.writeln('Created:');
    for (final file in plan.files) {
      io.stdout.writeln('  ${file.path}');
    }
    io.stdout
      ..writeln('\nEdited:')
      ..writeln('  $routerPath');
    for (final path in plan.arbContents.keys) {
      io.stdout.writeln('  $path');
    }
    if (plan.untranslated.isNotEmpty) {
      io.stdout.writeln(
        '\nThese carry the ENGLISH text and still need translating:',
      );
      plan.untranslated.forEach((path, keys) {
        io.stdout.writeln('  $path: ${keys.join(', ')}');
      });
    }
    io.stdout
      ..writeln('\nNext:')
      ..writeln('  flutter gen-l10n')
      ..writeln('  flutter analyze && flutter test');
    if (!tab) {
      io.stdout.writeln("\nNavigate to it with: context.go('/$name')");
    }
  }
}
