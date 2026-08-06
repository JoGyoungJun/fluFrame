import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:fluframe/src/process_runner.dart';
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

  /// Existed in the base template but the user removed or renamed it;
  /// reported only, never restored (unless `--restore-deleted`).
  deletedLocally,
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
       _runProcess = runProcess ?? defaultRunProcess,
       _log = log ?? stdout;

  /// The currently installed `templates/app` directory.
  final Directory currentTemplate;

  final BundleProvider _oldBundle;
  final RunProcess _runProcess;
  final StringSink _log;

  /// Runs the upgrade; dry-run unless [apply] is set. Returns an exit
  /// code.
  ///
  /// [force] skips the "can this be undone" gate that [apply] otherwise
  /// requires (a git repository with a clean working tree).
  ///
  /// [restoreDeleted] brings back template files the user removed, which
  /// is off by default — see [UpgradeStatus.deletedLocally].
  Future<int> run({
    required Directory projectDir,
    String? fromOverride,
    bool apply = false,
    bool force = false,
    bool restoreDeleted = false,
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

    // Both gates run before the bundle download: being told "commit first"
    // after a minute of network I/O is a worse experience than being told
    // immediately.
    final gitAvailable = await _probeGit();
    if (apply && !gitAvailable) {
      _log.writeln(
        'git not found on PATH — fluframe merges template updates with '
        'git merge-file. Install git (https://git-scm.com/downloads), or '
        'drop --apply to see the differences as a report.',
      );
      return ExitCode.unavailable.code;
    }
    if (apply && !force && !await _canUndo(projectDir)) {
      return ExitCode.usage.code;
    }
    if (!gitAvailable) {
      _log.writeln(
        'git not found on PATH — reporting differences only; install git '
        'to let fluframe merge them (--apply is disabled).',
      );
    }

    _log.writeln('Fetching the fluframe $from template bundle...');
    final oldTemplates = await _oldBundle(from);

    final work = Directory.systemTemp.createTempSync('fluframe_upgrade_');
    Future<Directory?> bare(
      Directory template,
      String label, {
      bool withAddons = true,
    }) async {
      // Prefer the addon definitions the bundle ships with. Patch anchors
      // are exact strings from the template of that era, so applying this
      // CLI's anchors to an older bundle breaks the moment the template
      // moves one of those lines.
      final registry = _readAddonRegistry(template.parent);
      final generator = ProjectGenerator(
        templateDirectory: template,
        runProcess: _runProcess,
        log: _log,
        addons: registry?.backends,
        errorAddons: registry?.errorReporting,
        analytics: registry?.analytics,
      );
      final code = await generator.generate(
        name: name,
        org: org,
        outputDirectory: p.join(work.path, label),
        backend: withAddons ? backend : null,
        errorReporting: withAddons ? errorReporting : null,
        analytics: withAddons ? analytics : null,
        bareOverlay: true,
      );
      if (code != 0) return null;
      return Directory(p.join(work.path, label, name));
    }

    final oldApp = Directory(p.join(oldTemplates.path, 'app'));
    var baseDir = await bare(oldApp, 'base');
    var theirsDir = baseDir == null
        ? null
        : await bare(currentTemplate, 'theirs');
    if (baseDir == null || theirsDir == null) {
      // Degrade rather than abort, and degrade BOTH sides so they stay
      // comparable. The addons may be unreplayable because the old bundle
      // predates the current anchors, or because the addon has since been
      // dropped from the CLI. Either way the files those addons touch
      // simply report as conflicts, which a user can resolve — whereas
      // giving up here left every app generated with any addon
      // permanently un-upgradable, at exit 70.
      _log.writeln(
        'Could not replay the recorded addons against both the fluframe '
        '$from bundle and this one, so the merge base was rebuilt without '
        'them. Files those addons touch will likely report as conflicts.',
      );
      baseDir = await bare(oldApp, 'base-plain', withAddons: false);
      theirsDir = await bare(
        currentTemplate,
        'theirs-plain',
        withAddons: false,
      );
    }
    if (baseDir == null || theirsDir == null) {
      _log.writeln('Could not reconstruct the templates to compare.');
      return ExitCode.software.code;
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
        if (base != null && !restoreDeleted) {
          // The file shipped in the version this app was generated with,
          // so the user deleted or renamed it. ADR 0002 never deletes on
          // their behalf; restoring is the same overreach in reverse —
          // and a renamed file comes back as a second declaration of the
          // same class, which does not compile.
          results[relative] = UpgradeStatus.deletedLocally;
          continue;
        }
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
      // A hard merge failure yields no content; leave the file untouched
      // rather than overwriting it with nothing.
      if (content != null) merged[relative] = content;
    }

    for (final relative in _walk(baseDir)) {
      if (File(p.join(theirsDir.path, relative)).existsSync()) continue;
      if (!File(p.join(projectDir.path, relative)).existsSync()) continue;
      results[relative] = UpgradeStatus.removedUpstream;
    }

    _report(from, results, unchanged, apply: apply);

    if (apply) {
      for (final entry in results.entries) {
        final content = merged[entry.key];
        if (content == null) continue; // removedUpstream: never delete.
        File(p.join(projectDir.path, entry.key))
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(content);
      }
      final conflicts = results.values
          .where((status) => status == UpgradeStatus.conflict)
          .length;
      // Record the new version only once the tree actually matches it.
      // Otherwise the `from == cliVersion` short-circuit above locks the
      // user out of re-running after they resolve the markers, and the
      // only way back is hand-editing .fluframe.json.
      if (conflicts == 0) {
        meta = {...meta, 'cliVersion': cliVersion};
        metaFile.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
        );
      }
      _log
        ..writeln()
        ..writeln('Applied. Next steps:');
      if (conflicts > 0) {
        _log
          ..writeln(
            '  resolve $conflicts file(s) marked CONFLICT '
            '(standard git markers)',
          )
          ..writeln('  then re-run: fluframe upgrade --apply')
          ..writeln('  (.fluframe.json stays at $from until they are gone)');
        return ExitCode.software.code;
      }
      _log.writeln('  flutter pub get && dart fix --apply && flutter test');
    } else if (results.isNotEmpty) {
      _log.writeln('\nDry run — re-run with --apply to write these changes.');
    }
    return ExitCode.success.code;
  }

  /// Reads `addons.json` from a bundle root, or `null` when the bundle
  /// predates it (every version through 1.1.0) or the file is unusable.
  AddonRegistry? _readAddonRegistry(Directory bundleRoot) {
    final file = File(p.join(bundleRoot.path, addonRegistryFileName));
    if (!file.existsSync()) return null;
    try {
      return decodeAddonRegistry(
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>,
      );
    } on FormatException catch (error) {
      _log.writeln(
        'Ignoring ${file.path}: ${error.message}. Falling back to this '
        "version's addon definitions.",
      );
      return null;
    }
  }

  Future<bool> _probeGit() async {
    try {
      final result = await _runProcess('git', ['--version']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  /// Whether `--apply` can be undone.
  ///
  /// `--apply` overwrites files in place and keeps no backup, so the user
  /// needs their own way back: a git repository with a clean working
  /// tree. `flutter create` does not run `git init`, so a freshly
  /// generated app fails this check until the user makes their first
  /// commit.
  Future<bool> _canUndo(Directory projectDir) async {
    final ProcessResult status;
    try {
      status = await _runProcess(
        'git',
        ['status', '--porcelain'],
        workingDirectory: projectDir.path,
      );
    } on ProcessException catch (error) {
      _log.writeln('Could not inspect ${projectDir.path}: ${error.message}');
      return false;
    }
    if (status.exitCode != 0) {
      _log.writeln(
        'This app is not a git repository, so --apply could not be undone.\n'
        '  git init && git add -A && git commit -m "before fluframe upgrade"\n'
        'then re-run, or pass --force to skip this check.',
      );
      return false;
    }
    if (status.stdout.toString().trim().isNotEmpty) {
      _log.writeln(
        'Working tree has uncommitted changes, so --apply could not be '
        'undone. Commit or stash them first, or pass --force.',
      );
      return false;
    }
    return true;
  }

  /// Three-way merges one file, returning its new content — or `null`
  /// when git could not merge it at all, in which case the caller must
  /// leave the user's copy alone.
  Future<(UpgradeStatus, String?)> _mergeFile({
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
      // No `-p`: git writes the merged result back into `oursFile`, so the
      // bytes never round-trip through a pipe — where they would be
      // re-encoded and, on a non-UTF-8 console codepage, corrupted.
      final result = await _runProcess('git', [
        'merge-file',
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
      // git merge-file exits with the conflict count (clamped to 127), or
      // negatively on a hard error such as binary input. Anything outside
      // 0..127 means nothing was merged.
      if (result.exitCode < 0 || result.exitCode > 127) {
        _log.writeln(
          'git merge-file failed (${result.stderr.toString().trim()}) — '
          'leaving this file untouched.',
        );
        return (UpgradeStatus.conflict, null);
      }
      final content = oursFile.readAsStringSync().replaceAll('\r\n', '\n');
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
      UpgradeStatus.deletedLocally: '-',
    };
    for (final entry in results.entries) {
      final suffix = switch (entry.value) {
        UpgradeStatus.conflict => ' (CONFLICT)',
        UpgradeStatus.removedUpstream => ' (removed upstream - kept)',
        UpgradeStatus.deletedLocally => ' (deleted locally - not restored)',
        _ => '',
      };
      _log.writeln('  ${labels[entry.value]} ${entry.key}$suffix');
    }
    if (results.isEmpty) {
      _log.writeln('  Nothing to change — the app already matches.');
    }
  }
}
