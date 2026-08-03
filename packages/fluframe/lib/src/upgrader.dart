import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/bundle_archive.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:fluframe/src/version.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

/// How a single file fared during an upgrade (spec 002).
enum UpgradeStatus {
  /// New in the current template; copied on `--apply`.
  added,

  /// Upstream changed, local untouched (or merge resolved cleanly).
  cleanMerge,

  /// Both sides changed — written with git conflict markers on apply.
  conflict,

  /// Existed in the base template but the current one dropped it;
  /// reported only, never deleted.
  removedUpstream,
}

/// Applies template updates to an existing generated app via a
/// per-file three-way merge (ADR 0002): BASE = the bundle of the
/// version the app was generated with (from the pub.dev archive),
/// THEIRS = the current bundle, OURS = the user's working tree.
class Upgrader {
  /// Creates an upgrader reading the current app template from
  /// [currentTemplate].
  Upgrader({
    required this.currentTemplate,
    BundleProvider? oldBundleProvider,
    RunProcess? runProcess,
    StringSink? log,
  }) : _oldBundle = oldBundleProvider ?? downloadPublishedBundle,
       _runProcess = runProcess ?? _defaultRunProcess,
       _log = log ?? stdout;

  /// The currently installed `templates/app` directory.
  final Directory currentTemplate;

  final BundleProvider _oldBundle;
  final RunProcess _runProcess;
  final StringSink _log;

  static Future<ProcessResult> _defaultRunProcess(
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

  /// Runs the upgrade; dry-run unless [apply] is set. Returns an exit
  /// code.
  Future<int> run({
    required Directory projectDir,
    String? fromOverride,
    bool apply = false,
  }) async {
    final metaFile = File(p.join(projectDir.path, '.fluframe.json'));
    var meta = const <String, dynamic>{};
    if (metaFile.existsSync()) {
      meta = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
    }
    final from = fromOverride ?? meta['cliVersion'] as String?;
    if (from == null) {
      _log.writeln(
        'No .fluframe.json found and no --from given. Apps generated '
        'before fluframe 0.14.0 must pass --from <version> (the fluframe '
        'version they were created with).',
      );
      return ExitCode.usage.code;
    }
    if (from == cliVersion) {
      _log.writeln(
        'Already generated with fluframe $cliVersion — '
        'nothing to upgrade.',
      );
      return ExitCode.success.code;
    }

    final name =
        meta['name'] as String? ?? p.basename(projectDir.absolute.path);
    final org = meta['org'] as String? ?? 'com.example';
    final backend = meta['backend'] as String?;
    final errorReporting = meta['errorReporting'] as String?;
    final analytics = meta['analytics'] as String?;

    _log.writeln('Fetching the fluframe $from template bundle...');
    final oldTemplates = await _oldBundle(from);

    final work = Directory.systemTemp.createTempSync('fluframe_upgrade_');
    Future<Directory?> bare(Directory template, String label) async {
      final generator = ProjectGenerator(
        templateDirectory: template,
        runProcess: _runProcess,
        log: _log,
      );
      final code = await generator.generate(
        name: name,
        org: org,
        outputDirectory: p.join(work.path, label),
        backend: backend,
        errorReporting: errorReporting,
        analytics: analytics,
        bareOverlay: true,
      );
      if (code != 0) {
        _log.writeln(
          'Could not reconstruct the $label overlay (see above) — the '
          'recorded addon set may predate the current addon definitions.',
        );
        return null;
      }
      return Directory(p.join(work.path, label, name));
    }

    final baseDir = await bare(
      Directory(p.join(oldTemplates.path, 'app')),
      'base',
    );
    final theirsDir = await bare(currentTemplate, 'theirs');
    if (baseDir == null || theirsDir == null) return ExitCode.software.code;

    final gitAvailable = await _probeGit();
    if (!gitAvailable) {
      _log.writeln(
        'git not found on PATH — reporting differences only; install git '
        'to let fluframe merge them (--apply is disabled).',
      );
    }

    final results = <String, UpgradeStatus>{};
    final merged = <String, String>{};
    var unchanged = 0;

    final theirFiles = _walk(theirsDir);
    for (final relative in theirFiles) {
      final theirs = _readNormalized(File(p.join(theirsDir.path, relative)));
      final baseFile = File(p.join(baseDir.path, relative));
      final ourFile = File(p.join(projectDir.path, relative));
      final base = baseFile.existsSync() ? _readNormalized(baseFile) : null;
      final ours = ourFile.existsSync() ? _readNormalized(ourFile) : null;

      if (base == theirs) {
        unchanged++;
        continue; // Nothing changed upstream; local state wins untouched.
      }
      if (ours == null) {
        results[relative] = UpgradeStatus.added;
        merged[relative] = theirs;
        continue;
      }
      if (ours == theirs) {
        unchanged++;
        continue; // Local already matches the new template.
      }
      if (!gitAvailable) {
        results[relative] = UpgradeStatus.conflict;
        continue;
      }
      final (status, content) = await _mergeFile(
        base: base ?? '',
        ours: ours,
        theirs: theirs,
      );
      results[relative] = status;
      merged[relative] = content;
    }

    for (final relative in _walk(baseDir)) {
      if (File(p.join(theirsDir.path, relative)).existsSync()) continue;
      if (!File(p.join(projectDir.path, relative)).existsSync()) continue;
      results[relative] = UpgradeStatus.removedUpstream;
    }

    _report(from, results, unchanged, apply: apply);

    if (apply && gitAvailable) {
      for (final entry in results.entries) {
        final content = merged[entry.key];
        if (content == null) continue; // removedUpstream: never delete.
        File(p.join(projectDir.path, entry.key))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(content);
      }
      meta = {...meta, 'cliVersion': cliVersion};
      metaFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
      );
      _log
        ..writeln()
        ..writeln('Applied. Next steps:')
        ..writeln('  flutter pub get && dart fix --apply && flutter test')
        ..writeln(
          '  resolve any files marked CONFLICT (standard git markers)',
        );
    } else if (apply && !gitAvailable) {
      return ExitCode.unavailable.code;
    } else if (results.isNotEmpty) {
      _log.writeln('\nDry run — re-run with --apply to write these changes.');
    }
    return ExitCode.success.code;
  }

  Future<bool> _probeGit() async {
    try {
      final result = await _runProcess('git', ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  Future<(UpgradeStatus, String)> _mergeFile({
    required String base,
    required String ours,
    required String theirs,
  }) async {
    final dir = Directory.systemTemp.createTempSync('fluframe_merge_');
    try {
      final oursFile = File(p.join(dir.path, 'ours'))..writeAsStringSync(ours);
      final baseFile = File(p.join(dir.path, 'base'))..writeAsStringSync(base);
      final theirsFile = File(p.join(dir.path, 'theirs'))
        ..writeAsStringSync(theirs);
      final result = await _runProcess('git', [
        'merge-file',
        '-p',
        '-L',
        'yours',
        '-L',
        'base',
        '-L',
        'fluframe-template',
        oursFile.path,
        baseFile.path,
        theirsFile.path,
      ]);
      final content = result.stdout.toString();
      return result.exitCode == 0
          ? (UpgradeStatus.cleanMerge, content)
          : (UpgradeStatus.conflict, content);
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException {
        // Temp cleanup best-effort.
      }
    }
  }

  List<String> _walk(Directory root) {
    return [
      for (final entity in root.listSync(recursive: true))
        if (entity is File)
          p.relative(entity.path, from: root.path).replaceAll(r'\', '/'),
    ]..sort();
  }

  String _readNormalized(File file) =>
      file.readAsStringSync().replaceAll('\r\n', '\n');

  void _report(
    String from,
    Map<String, UpgradeStatus> results,
    int unchanged, {
    required bool apply,
  }) {
    final counts = <UpgradeStatus, int>{};
    for (final status in results.values) {
      counts[status] = (counts[status] ?? 0) + 1;
    }
    _log
      ..writeln()
      ..writeln(
        'Upgrade $from -> $cliVersion (${apply ? 'apply' : 'dry run'})',
      )
      ..writeln(
        '  unchanged: $unchanged   '
        'added: ${counts[UpgradeStatus.added] ?? 0}   '
        'clean: ${counts[UpgradeStatus.cleanMerge] ?? 0}   '
        'conflicts: ${counts[UpgradeStatus.conflict] ?? 0}   '
        'removed upstream: ${counts[UpgradeStatus.removedUpstream] ?? 0}',
      );
    final labels = {
      UpgradeStatus.added: '+',
      UpgradeStatus.cleanMerge: '~',
      UpgradeStatus.conflict: '!',
      UpgradeStatus.removedUpstream: '-',
    };
    for (final entry in results.entries) {
      final suffix = switch (entry.value) {
        UpgradeStatus.conflict => ' (CONFLICT)',
        UpgradeStatus.removedUpstream => ' (removed upstream - kept)',
        _ => '',
      };
      _log.writeln('  ${labels[entry.value]} ${entry.key}$suffix');
    }
    if (results.isEmpty) {
      _log.writeln('  Nothing to change — the app already matches.');
    }
  }
}
