import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:fluframe/src/process_runner.dart';
import 'package:fluframe/src/version.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

export 'package:fluframe/src/process_runner.dart' show RunProcess;

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

/// Overlay entries whose absence leaves a generated app that cannot run.
///
/// The overlay deletes the scaffold's `lib/` before copying, so a bundle
/// missing `lib` produces a project with no source at all — previously a
/// warning followed by "Created my_app at ...". Addons already fail loudly
/// on a missing file (ADR 0001); the app itself must too.
const Set<String> requiredOverlayEntries = {'lib', 'test', 'pubspec.yaml'};

/// Platforms `flutter create` is asked for when the user does not choose.
///
/// Single source of truth for `ProjectGenerator.generate` and the
/// `--platforms` option, which drifted apart as two copies of the literal.
const List<String> defaultPlatforms = [
  'android',
  'ios',
  'web',
  'windows',
  'macos',
  'linux',
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
    Map<String, BackendAddon>? errorAddons,
    Map<String, BackendAddon>? analytics,
  }) : _runProcess = runProcess ?? defaultRunProcess,
       _log = log ?? stdout,
       _addons = addons ?? backendAddons,
       _errorAddons = errorAddons ?? errorReportingAddons,
       _analytics = analytics ?? analyticsAddons;

  /// Root of the template to copy from.
  final Directory templateDirectory;

  final RunProcess _runProcess;
  final StringSink _log;
  final Map<String, BackendAddon> _addons;
  final Map<String, BackendAddon> _errorAddons;
  final Map<String, BackendAddon> _analytics;

  /// Generates the project and returns a process exit code.
  Future<int> generate({
    required String name,
    required String org,
    required String outputDirectory,
    String? description,
    String? backend,
    String? errorReporting,
    String? analytics,
    List<String> platforms = defaultPlatforms,
    bool runPub = true,
    bool bareOverlay = false,
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
    final BackendAddon? reporting;
    if (errorReporting == null) {
      reporting = null;
    } else {
      reporting = _errorAddons[errorReporting];
      if (reporting == null) {
        _log.writeln(
          'Unknown error-reporting service "$errorReporting". '
          'Available: ${_errorAddons.keys.join(', ')}.',
        );
        return ExitCode.usage.code;
      }
    }
    final BackendAddon? analyticsAddon;
    if (analytics == null) {
      analyticsAddon = null;
    } else {
      analyticsAddon = _analytics[analytics];
      if (analyticsAddon == null) {
        _log.writeln(
          'Unknown analytics service "$analytics". '
          'Available: ${_analytics.keys.join(', ')}.',
        );
        return ExitCode.usage.code;
      }
    }

    final targetPath = p.join(outputDirectory, name);
    if (Directory(targetPath).existsSync()) {
      _log.writeln('Directory "$targetPath" already exists. Aborting.');
      return ExitCode.usage.code;
    }

    if (bareOverlay) {
      // Upgrade support (spec 002): produce ONLY the overlay output —
      // no platform scaffold, no pub, no metadata — as merge input.
      Directory(targetPath).createSync(recursive: true);
      // Deliberately not gated on requiredOverlayEntries: this rebuilds an
      // arbitrary historical bundle for the upgrader, and a gap there is
      // better reported as a per-file difference than as a hard stop that
      // makes the app un-upgradable.
      _applyOverlay(targetPath, name: name, description: description);
      for (final selected in [addon, reporting, analyticsAddon]) {
        if (selected == null) continue;
        final addonExit = await _applyBackendAddon(
          targetPath,
          addon: selected,
          name: name,
          installDependencies: false,
        );
        if (addonExit != 0) return addonExit;
      }
      return ExitCode.success.code;
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
      _logPartialOutput(targetPath);
      return ExitCode.software.code;
    }

    _log.writeln('Applying the fluFrame template...');
    final incomplete = _rejectIncompleteBundle(
      _applyOverlay(targetPath, name: name, description: description),
      targetPath,
    );
    if (incomplete != null) return incomplete;

    for (final selected in [addon, reporting, analyticsAddon]) {
      if (selected == null) continue;
      _log.writeln('Applying the ${selected.name} addon...');
      final addonExit = await _applyBackendAddon(
        targetPath,
        addon: selected,
        name: name,
      );
      if (addonExit != 0) {
        _logPartialOutput(targetPath);
        return addonExit;
      }
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
        if (Platform.isWindows &&
            pubGet.stderr.toString().toLowerCase().contains('symlink')) {
          _log.writeln(
            'The default platforms include windows and linux, whose plugins '
            'need symbolic links. Enable Developer Mode '
            '(start ms-settings:developers) and retry — fluframe doctor '
            'checks this up front.',
          );
        }
        _logPartialOutput(targetPath);
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

    // Generation metadata — the contract `fluframe upgrade` reads to
    // reconstruct this exact generation later (design spec 002). Written
    // last so its presence means "this app was generated successfully";
    // a half-written directory the user is told to delete must not look
    // upgradable.
    File(p.join(targetPath, '.fluframe.json')).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({
        'schema': 1,
        'cliVersion': cliVersion,
        'name': name,
        'org': org,
        'backend': backend,
        'errorReporting': errorReporting,
        'analytics': analytics,
      })}\n',
    );

    _log
      ..writeln()
      ..writeln('Created $name at $targetPath.')
      ..writeln()
      ..writeln('Next steps:')
      ..writeln('  cd $targetPath')
      ..writeln('  flutter run --dart-define-from-file=env/dev.json');
    for (final note in [
      ...?addon?.postCreateNotes,
      ...?reporting?.postCreateNotes,
      ...?analyticsAddon?.postCreateNotes,
    ]) {
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
    bool installDependencies = true,
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
      if (addon.requiresFiles) {
        _log.writeln(
          'Addon files for "${addon.name}" not found near the '
          'template (${addonDir.path}). Reinstall with: '
          'dart pub global activate fluframe',
        );
        return ExitCode.software.code;
      }
      // Patch-only addon — nothing to copy.
    } else {
      _copyDirectory(addonDir, Directory(targetPath), name: name);
    }

    for (final patch in addon.patches) {
      final file = File(p.join(targetPath, patch.file));
      if (!file.existsSync()) {
        _log.writeln(
          'Addon patch target missing: ${patch.file} — the template and '
          'the ${addon.name} addon are out of sync.',
        );
        return ExitCode.software.code;
      }
      // Normalize CRLF so multi-line anchors match regardless of how git
      // checked the template out on this machine.
      final content = file.readAsStringSync().replaceAll('\r\n', '\n');
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

    if (installDependencies && addon.dependencies.isNotEmpty) {
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

  /// Copies the template over the `flutter create` scaffold.
  ///
  /// Returns the overlay entries that were missing from the bundle.
  List<String> _applyOverlay(
    String targetPath, {
    required String name,
    String? description,
  }) {
    final missing = <String>[];
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
        missing.add(entry);
        _log.writeln(
          'Warning: template entry "$entry" not found — skipped.',
        );
      }
    }

    // Guarded on existence: a bundle without pubspec.yaml is rejected by
    // the caller, and throwing here would pre-empt that message.
    final pubspec = File(p.join(targetPath, 'pubspec.yaml'));
    if (description != null && pubspec.existsSync()) {
      final content = pubspec.readAsStringSync().replaceFirst(
        RegExp('^description: .*', multiLine: true),
        'description: "${_escapeYamlDoubleQuoted(description)}"',
      );
      pubspec.writeAsStringSync(content);
    }
    return missing;
  }

  /// Fails the run when the bundle was missing something the app needs.
  ///
  /// Returns `null` when [missing] contains nothing essential.
  int? _rejectIncompleteBundle(List<String> missing, String targetPath) {
    final essential = missing.where(requiredOverlayEntries.contains).toList();
    if (essential.isEmpty) return null;
    _log.writeln(
      'The fluFrame template bundle is incomplete (missing: '
      '${essential.join(', ')}), so the generated app would not run. '
      'Reinstall with: dart pub global activate fluframe',
    );
    _logPartialOutput(targetPath);
    return ExitCode.software.code;
  }

  /// Tells the user where the half-written project is and how to clear it.
  ///
  /// Every failure that reaches here happens after we created [targetPath]
  /// ourselves — the `existsSync` guard in [generate] runs before anything
  /// is written, so the directory is never one the user already had.
  /// Without this, a retry after fixing the cause hits
  /// `Directory "..." already exists. Aborting.`
  void _logPartialOutput(String targetPath) {
    _log
      ..writeln()
      ..writeln('Partial output left at: $targetPath')
      ..writeln(
        'Remove it before retrying: '
        '${Platform.isWindows ? 'rmdir /s /q' : 'rm -rf'} $targetPath',
      );
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
