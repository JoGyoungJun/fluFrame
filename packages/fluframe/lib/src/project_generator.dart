import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

/// Signature of a process launcher, injectable for tests.
typedef RunProcess =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

Future<ProcessResult> _defaultRunProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
}

/// Template package name that gets rewritten into the new project's name.
const String templatePackageName = 'fluframe_app';

/// Template display name that gets rewritten into the humanized app title.
const String templateDisplayName = 'FluFrame App';

/// Korean template display name (`appTitle` in `app_ko.arb`), rewritten to
/// the humanized app title so generated apps carry no fluFrame branding in
/// any locale.
const String templateDisplayNameKo = 'FluFrame 앱';

/// Japanese template display name (`appTitle` in `app_ja.arb`).
const String templateDisplayNameJa = 'FluFrame アプリ';

/// Files and directories copied from the template over a fresh
/// `flutter create` output.
///
/// `.gitignore` is stored as `gitignore` (no dot) inside the published
/// bundle so its rules cannot influence pub's file selection; the overlay
/// restores the real name.
const List<String> overlayEntries = [
  'lib',
  'test',
  'env',
  'l10n.yaml',
  'analysis_options.yaml',
  'README.md',
  'pubspec.yaml',
  '.gitignore',
];

/// File extensions treated as text and run through the token rewriter.
const Set<String> _textExtensions = {
  '.dart',
  '.yaml',
  '.yml',
  '.arb',
  '.json',
  '.md',
};

/// Rewrites template tokens in [content] for a project called [projectName].
String rewriteTemplateContent(String content, {required String projectName}) {
  final displayName = humanizePackageName(projectName);
  return content
      .replaceAll(templatePackageName, projectName)
      .replaceAll(templateDisplayName, displayName)
      .replaceAll(templateDisplayNameKo, '$displayName 앱')
      .replaceAll(templateDisplayNameJa, '$displayName アプリ');
}

/// Escapes [value] for use inside a YAML double-quoted scalar.
String _escapeYamlDoubleQuoted(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\r', ' ')
    .replaceAll('\n', ' ');

/// Generates a new Flutter project from the fluFrame template.
///
/// Pipeline: `flutter create --empty` (real platform folders for the
/// current Flutter version) → overlay the template's `lib/`, `test/` and
/// config files → rewrite package-name tokens → `flutter pub get` +
/// `flutter gen-l10n`.
class ProjectGenerator {
  /// Creates a generator reading from [templateDirectory].
  ProjectGenerator({
    required this.templateDirectory,
    RunProcess? runProcess,
    StringSink? log,
    Map<String, BackendAddon>? addons,
  }) : _runProcess = runProcess ?? _defaultRunProcess,
       _log = log ?? stdout,
       _addons = addons ?? backendAddons;

  /// Root of the template to copy from.
  final Directory templateDirectory;

  final RunProcess _runProcess;
  final StringSink _log;
  final Map<String, BackendAddon> _addons;

  /// Generates the project and returns a process exit code.
  Future<int> generate({
    required String name,
    required String org,
    required String outputDirectory,
    String? description,
    String? backend,
    List<String> platforms = const [
      'android',
      'ios',
      'web',
      'windows',
      'macos',
      'linux',
    ],
    bool runPub = true,
  }) async {
    final BackendAddon? addon;
    if (backend == null) {
      addon = null;
    } else {
      addon = _addons[backend];
      if (addon == null) {
        _log.writeln(
          'Unknown backend "$backend". '
          'Available: ${_addons.keys.join(', ')}.',
        );
        return ExitCode.usage.code;
      }
    }

    final targetPath = p.join(outputDirectory, name);
    if (Directory(targetPath).existsSync()) {
      _log.writeln('Directory "$targetPath" already exists. Aborting.');
      return ExitCode.usage.code;
    }

    _log.writeln('Scaffolding $name with flutter create...');
    final ProcessResult create;
    try {
      create = await _runProcess('flutter', [
        'create',
        targetPath,
        '--project-name',
        name,
        '--org',
        org,
        '--platforms=${platforms.join(',')}',
        '--empty',
      ]);
    } on ProcessException {
      _logFlutterMissing();
      return ExitCode.unavailable.code;
    }
    if (create.exitCode != 0) {
      // With runInShell (Windows) a missing command surfaces as a shell
      // error exit instead of a ProcessException: 9009 (cmd) / 127 (POSIX).
      final stderrText = create.stderr.toString();
      if (create.exitCode == 9009 ||
          create.exitCode == 127 ||
          stderrText.contains('is not recognized') ||
          stderrText.contains('command not found')) {
        _logFlutterMissing();
        return ExitCode.unavailable.code;
      }
      _log
        ..writeln('flutter create failed:')
        ..writeln(create.stderr);
      return ExitCode.software.code;
    }

    _log.writeln('Applying the fluFrame template...');
    _applyOverlay(targetPath, name: name, description: description);

    if (addon != null) {
      _log.writeln('Applying the ${addon.name} backend addon...');
      final addonExit = await _applyBackendAddon(
        targetPath,
        addon: addon,
        name: name,
      );
      if (addonExit != 0) return addonExit;
    }

    if (runPub) {
      _log.writeln('Resolving dependencies...');
      final pubGet = await _runProcess('flutter', [
        'pub',
        'get',
      ], workingDirectory: targetPath);
      if (pubGet.exitCode != 0) {
        _log
          ..writeln('flutter pub get failed:')
          ..writeln(pubGet.stderr);
        return ExitCode.software.code;
      }
      // Renaming the package can change the alphabetical order of imports
      // (e.g. `demo_app` sorts before `dio`); dart fix re-sorts them.
      _log.writeln('Tidying imports (dart fix)...');
      final fix = await _runProcess(
        'dart',
        ['fix', '--apply'],
        workingDirectory: targetPath,
      );
      if (fix.exitCode != 0) {
        _log
          ..writeln(
            'Warning: dart fix failed — run it manually, or '
            'flutter analyze may report import-ordering issues:',
          )
          ..writeln(fix.stderr);
      }
      final genL10n = await _runProcess(
        'flutter',
        ['gen-l10n'],
        workingDirectory: targetPath,
      );
      if (genL10n.exitCode != 0) {
        _log
          ..writeln('Warning: flutter gen-l10n failed (continuing):')
          ..writeln(genL10n.stderr);
      }
    }

    _log
      ..writeln()
      ..writeln('Created $name at $targetPath.')
      ..writeln()
      ..writeln('Next steps:')
      ..writeln('  cd $targetPath')
      ..writeln('  flutter run --dart-define-from-file=env/dev.json');
    for (final note in addon?.postCreateNotes ?? const <String>[]) {
      _log.writeln('  * $note');
    }
    return ExitCode.success.code;
  }

  /// Copies the addon's bundled files, applies its anchored patches, and
  /// installs its dependencies. A missing addon directory or patch anchor
  /// fails loudly (ADR 0001) — never a silently broken app.
  Future<int> _applyBackendAddon(
    String targetPath, {
    required BackendAddon addon,
    required String name,
  }) async {
    final parent = templateDirectory.parent.path;
    final addonDir =
        [
          Directory(p.join(parent, 'addons', addon.name)),
          Directory(p.join(parent, 'template_addons', addon.name)),
        ].firstWhere(
          (dir) => dir.existsSync(),
          orElse: () => Directory(p.join(parent, 'addons', addon.name)),
        );
    if (!addonDir.existsSync()) {
      _log.writeln(
        'Backend addon files for "${addon.name}" not found near the '
        'template (${addonDir.path}). Reinstall with: '
        'dart pub global activate fluframe',
      );
      return ExitCode.software.code;
    }
    _copyDirectory(addonDir, Directory(targetPath), name: name);

    for (final patch in addon.patches) {
      final file = File(p.join(targetPath, patch.file));
      if (!file.existsSync()) {
        _log.writeln(
          'Addon patch target missing: ${patch.file} — the template and '
          'the ${addon.name} addon are out of sync.',
        );
        return ExitCode.software.code;
      }
      final content = file.readAsStringSync();
      final anchor = rewriteTemplateContent(patch.anchor, projectName: name);
      if (!content.contains(anchor)) {
        _log.writeln(
          'Addon patch anchor not found in ${patch.file}:\n  $anchor\n'
          'The template and the ${addon.name} addon are out of sync.',
        );
        return ExitCode.software.code;
      }
      file.writeAsStringSync(
        content.replaceFirst(
          anchor,
          rewriteTemplateContent(patch.replacement, projectName: name),
        ),
      );
    }

    if (addon.dependencies.isNotEmpty) {
      _log.writeln(
        'Adding dependencies: ${addon.dependencies.join(', ')}...',
      );
      final pubAdd = await _runProcess('flutter', [
        'pub',
        'add',
        ...addon.dependencies,
      ], workingDirectory: targetPath);
      if (pubAdd.exitCode != 0) {
        _log
          ..writeln('flutter pub add failed:')
          ..writeln(pubAdd.stderr);
        return ExitCode.software.code;
      }
    }
    return ExitCode.success.code;
  }

  void _logFlutterMissing() {
    _log
      ..writeln('Flutter SDK not found on PATH.')
      ..writeln(
        'Install it first: https://docs.flutter.dev/get-started/install',
      )
      ..writeln('Then verify with: flutter --version');
  }

  void _applyOverlay(
    String targetPath, {
    required String name,
    String? description,
  }) {
    // The template's lib/ fully replaces the scaffold's lib/.
    final scaffoldLib = Directory(p.join(targetPath, 'lib'));
    if (scaffoldLib.existsSync()) {
      scaffoldLib.deleteSync(recursive: true);
    }

    for (final entry in overlayEntries) {
      // Inside the published bundle .gitignore is stored dot-less.
      var source = p.join(templateDirectory.path, entry);
      if (entry == '.gitignore' && !FileSystemEntity.isFileSync(source)) {
        source = p.join(templateDirectory.path, 'gitignore');
      }
      final destination = p.join(targetPath, entry);
      if (FileSystemEntity.isDirectorySync(source)) {
        _copyDirectory(Directory(source), Directory(destination), name: name);
      } else if (FileSystemEntity.isFileSync(source)) {
        _copyFile(File(source), File(destination), name: name);
      } else {
        _log.writeln(
          'Warning: template entry "$entry" not found — skipped.',
        );
      }
    }

    if (description != null) {
      final pubspec = File(p.join(targetPath, 'pubspec.yaml'));
      final content = pubspec.readAsStringSync().replaceFirst(
        RegExp('^description: .*', multiLine: true),
        'description: "${_escapeYamlDoubleQuoted(description)}"',
      );
      pubspec.writeAsStringSync(content);
    }
  }

  void _copyDirectory(
    Directory source,
    Directory destination, {
    required String name,
  }) {
    destination.createSync(recursive: true);
    for (final entity in source.listSync()) {
      final basename = p.basename(entity.path);
      final target = p.join(destination.path, basename);
      if (entity is Directory) {
        _copyDirectory(entity, Directory(target), name: name);
      } else if (entity is File) {
        _copyFile(entity, File(target), name: name);
      }
    }
  }

  void _copyFile(File source, File destination, {required String name}) {
    destination.parent.createSync(recursive: true);
    if (_textExtensions.contains(p.extension(source.path)) ||
        p.basename(destination.path) == '.gitignore') {
      final content = source.readAsStringSync();
      destination.writeAsStringSync(
        rewriteTemplateContent(content, projectName: name),
      );
    } else {
      source.copySync(destination.path);
    }
  }
}
