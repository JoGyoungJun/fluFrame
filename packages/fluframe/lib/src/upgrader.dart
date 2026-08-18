import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:fluframe/src/package_name.dart';
import 'package:fluframe/src/process_runner.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:fluframe/src/sdk_constraint.dart';
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

  /// One of the three sides holds no UTF-8 text (a binary asset, or a
  /// file saved in a legacy encoding), so it cannot be diffed or merged;
  /// reported and skipped, never written.
  unreadable,
}

/// One side of a merge, loaded from disk.
///
/// `text` has every line ending normalized to `\n` so the three sides are
/// compared and merged on content alone; `lineEnding` is what the bytes on
/// disk actually used, so a merged result can be written back in the style
/// the file already had.
typedef _Loaded = ({String text, String lineEnding});

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
    // Neither marker means this is not an app fluframe can upgrade, and
    // --apply would unpack a whole template into whatever directory the
    // shell happened to be in. --from stays usable for pre-0.14.0 apps:
    // they carry no metadata, but they do have a pubspec.yaml.
    if (!metaFile.existsSync() &&
        !File(p.join(projectDir.path, 'pubspec.yaml')).existsSync()) {
      _log.writeln(
        '${p.normalize(projectDir.absolute.path)} does not look like a '
        'generated app: no .fluframe.json and no pubspec.yaml. Run '
        'fluframe upgrade from the root of the app, or point at it with '
        '--project-dir.',
      );
      return ExitCode.usage.code;
    }
    var meta = const <String, dynamic>{};
    if (metaFile.existsSync()) {
      // Hand-editable, so every shape it can be in has to die as a
      // sentence. A bare `as` cast on a wrong type raised a TypeError,
      // which is an Error the top-level handler prints as "This is a bug"
      // with a stack trace (#187).
      final decoded = jsonDecode(metaFile.readAsStringSync());
      if (decoded is! Map<String, dynamic>) {
        _log.writeln(
          '.fluframe.json holds a ${decoded.runtimeType}, not an object. '
          'Fix it, or delete it and re-run with --from <version>.',
        );
        return ExitCode.data.code;
      }
      meta = decoded;
      // This list is exactly the set of keys read below with a bare
      // `as String?`. One that is read but not listed here is #187 again,
      // one key over: `backend`, `errorReporting` and `analytics` were,
      // and a number in any of them reached the cast as a TypeError.
      for (final key in [
        'cliVersion',
        'name',
        'org',
        'backend',
        'errorReporting',
        'analytics',
        _pendingVersionKey,
      ]) {
        final value = meta[key];
        if (value != null && value is! String) {
          _log.writeln(
            '.fluframe.json has "$key": $value — expected a string. '
            'Fix it, or delete the file and re-run with --from <version>.',
          );
          return ExitCode.data.code;
        }
      }
      // The recorded name reaches the filesystem: it is joined onto a
      // scratch directory to rebuild the merge base below, and
      // package:path's join discards everything before an absolute part,
      // so an absolute or climbing name aims that write outside the
      // scratch tree. `fluframe create` puts every name through this same
      // validator, so one it refuses cannot have come from a generated
      // app — and .fluframe.json ships inside every app, ungitignored.
      final metaName = meta['name'] as String?;
      if (metaName != null) {
        final rejection = packageNameRejection(metaName);
        if (rejection != null) {
          _log.writeln(
            '.fluframe.json has "name": "$metaName" — $rejection. Fix '
            'it, or delete the file and re-run with --from <version>.',
          );
          return ExitCode.data.code;
        }
      }
      final pendingFiles = meta[_pendingFilesKey];
      if (pendingFiles != null &&
          (pendingFiles is! List || pendingFiles.any((e) => e is! String))) {
        _log.writeln(
          '.fluframe.json has "$_pendingFilesKey" that is not a list of '
          'file paths. Fix it, or delete the file and re-run with '
          '--from <version>.',
        );
        return ExitCode.data.code;
      }
      // Those same strings are joined onto the project root to look for
      // conflict markers, so `..` or an absolute path there points the
      // check at a file outside the app. Same hygiene AddonPatch.fromJson
      // applies to a bundle's patch targets, for a file the user edits.
      if (pendingFiles is List) {
        for (final entry in pendingFiles.cast<String>()) {
          if (!_isProjectRelative(entry)) {
            _log.writeln(
              '.fluframe.json lists "$entry" under "$_pendingFilesKey", '
              'which is not a path inside the app. Fix it, or delete the '
              'file and re-run with --from <version>.',
            );
            return ExitCode.data.code;
          }
        }
      }
    }
    final from = fromOverride ?? meta['cliVersion'] as String?;
    // An upgrade that ended in conflicts left the tree already carrying
    // the new template's changes. Re-merging the same BASE would conflict
    // again — on the very file the user just resolved — so this finishes
    // the run in progress instead of starting it over (#166). Checked
    // BEFORE the from == null gate: finishing needs no `from`, and a
    // --from app's pending state used to dead-end on that gate with
    // "No .fluframe.json found" — about the very file fluframe had just
    // written (#178).
    final pending = meta[_pendingVersionKey] as String?;
    if (pending != null) {
      final unresolved = _stillConflicted(projectDir, meta);
      if (unresolved.isNotEmpty) {
        _log.writeln(
          'Upgrade to fluframe $pending is in progress, and '
          '${unresolved.length} file(s) still carry conflict markers:',
        );
        for (final file in unresolved) {
          _log.writeln('  ! $file');
        }
        _log.writeln('Resolve them, then re-run: fluframe upgrade --apply');
        return ExitCode.software.code;
      }
      if (!apply) {
        _log.writeln(
          'Upgrade to fluframe $pending is in progress and every conflict '
          'is resolved. Re-run with --apply to record it.',
        );
        return ExitCode.success.code;
      }
      meta = {...meta, 'cliVersion': pending}
        ..remove(_pendingVersionKey)
        ..remove(_pendingFilesKey);
      metaFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
      );
      _log.writeln('Conflicts resolved — now on fluframe $pending.');
      return ExitCode.success.code;
    }

    if (from == null) {
      _log.writeln(
        'No .fluframe.json found and no --from given. Apps generated '
        'before fluframe 0.14.0 must pass --from <version> (the fluframe '
        'version they were created with).',
      );
      return ExitCode.usage.code;
    }
    // A version that is not a version cannot name a published bundle, and
    // letting it through produced pub.dev's 400 with a "usually temporary"
    // hint for a permanent typo (#189).
    //
    // Matched whole, not with parseSemVer. That one is unanchored on
    // purpose — `fluframe doctor` feeds it entire tool banners, so it
    // finds the first major.minor.patch ANYWHERE in its input — which as
    // a gate accepts anything merely CONTAINING a version. `from` is
    // interpolated straight into the bundle URL path in bundle_archive,
    // so a recorded "1.0.0/../../../evil_pkg/versions/1.0.0" passed on
    // its leading 1.0.0 and RFC 3986 dot-segment removal in Uri.resolve
    // turned the request into another published package's archive (same
    // host, so not an SSRF). None of its bytes reach the user's tree —
    // writes are keyed on the local template, and git merge-file runs
    // without -p and without --diff3 — but it becomes the merge BASE,
    // and a BASE equal to THEIRS makes every file report as unchanged:
    // --apply then records the app as upgraded having received nothing,
    // and the `from == cliVersion` short circuit below seals it out of
    // every later upgrade. Anchoring parseSemVer itself would break
    // doctor, so the strictness lives here, one step from the URL. This
    // is the single funnel for both --from and the recorded cliVersion,
    // and it sits before every path to the fetch.
    if (!_versionPattern.hasMatch(from)) {
      _log.writeln(
        '"$from" is not a version number. It came from '
        '${fromOverride != null ? '--from' : '.fluframe.json'}; expected '
        'major.minor.patch, e.g. 1.4.0 — see '
        'https://pub.dev/packages/fluframe/versions',
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
    // Refuse to run backwards. With only the equality check above, an app
    // generated by a NEWER fluframe took that newer bundle as the merge
    // BASE and this CLI's older template as THEIRS, so the merge ran in
    // reverse: newer content was classified as a clean merge, overwritten,
    // and .fluframe.json was rewritten down to the older version — exit 0,
    // "Applied.", content silently gone (#167).
    final fromVersion = parseSemVer(from);
    final thisVersion = parseSemVer(cliVersion);
    if (fromVersion != null &&
        thisVersion != null &&
        _isNewer(fromVersion, thisVersion)) {
      _log
        ..writeln(
          'This app was generated with fluframe $from, which is newer than '
          'the $cliVersion you are running. Upgrading would merge the older '
          'template into it and roll the app back.',
        )
        ..writeln('Update the CLI first: dart pub global activate fluframe');
      return ExitCode.usage.code;
    }

    // The package name, not the folder name. `--from` apps have no
    // metadata to read it from, and a checkout directory, a monorepo path
    // like apps/mobile, or a renamed folder is not the Dart package name —
    // using it writes imports for a package that does not exist (#168).
    final name =
        meta['name'] as String? ??
        _packageNameFromPubspec(projectDir) ??
        p.basename(projectDir.absolute.path);
    // Both fallbacks are guesses, and neither is guaranteed to be a
    // package name: a monorepo folder, a quoted pubspec `name:`, or a
    // renamed checkout all land here. The recorded name was validated
    // where it was read; this covers the paths that bypass it, because
    // `name` is joined onto the scratch directory the merge base is
    // rebuilt in.
    final nameRejection = packageNameRejection(name);
    if (nameRejection != null) {
      _log.writeln(
        'Cannot upgrade as package "$name": $nameRejection. That name was '
        'read from pubspec.yaml or from the directory name — record the '
        'real one as "name" in .fluframe.json and re-run.',
      );
      return ExitCode.data.code;
    }
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

    // nightly.yml greps this literal: .github/workflows/nightly.yml, job
    // upgrade-canary, `grep -qF "Fetching the fluframe $FROM template
    // bundle..."`. It is that job's proof the run reached the network
    // rather than taking a short circuit. Reword it and the nightly goes
    // red with a log naming neither the string nor the workflow —
    // upgrader_test.dart pins it so the break lands here instead.
    _log.writeln('Fetching the fluframe $from template bundle...');
    final oldTemplates = await _oldBundle(from);

    final results = <String, UpgradeStatus>{};
    final merged = <String, String>{};
    var upToDate = 0;
    var localEdits = 0;

    final work = Directory.systemTemp.createTempSync('fluframe_upgrade_');
    try {
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

      final theirFiles = _walk(theirsDir);
      for (final relative in theirFiles) {
        final theirsFile = File(p.join(theirsDir.path, relative));
        final baseFile = File(p.join(baseDir.path, relative));
        final ourFile = File(p.join(projectDir.path, relative));
        final theirs = _load(theirsFile);
        final base = baseFile.existsSync() ? _load(baseFile) : null;
        final ours = ourFile.existsSync() ? _load(ourFile) : null;

        // A side that exists but cannot be decoded has to be skipped: it can
        // be neither compared nor rewritten. Skipped per file, though — one
        // binary asset used to take the whole run down with an uncaught
        // FormatException out of readAsStringSync.
        if (theirs == null ||
            (baseFile.existsSync() && base == null) ||
            (ourFile.existsSync() && ours == null)) {
          results[relative] = UpgradeStatus.unreadable;
          continue;
        }

        if (base?.text == theirs.text) {
          // Nothing changed upstream, so there is nothing to merge in and
          // the local copy stands either way. Which one it is still has to
          // be looked at: counting these as "unchanged" without opening the
          // user's file reported a fact about the two bundles as though it
          // were one about their app.
          if (ours?.text == theirs.text) {
            upToDate++;
          } else {
            localEdits++;
          }
          continue;
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
          merged[relative] = _restoreLineEndings(theirs);
          continue;
        }
        if (ours.text == theirs.text) {
          upToDate++;
          continue; // Local already matches the new template.
        }
        if (!gitAvailable) {
          results[relative] = UpgradeStatus.conflict;
          continue;
        }
        final (status, content) = await _mergeFile(
          base: base?.text ?? '',
          ours: ours.text,
          theirs: theirs.text,
        );
        results[relative] = status;
        // A hard merge failure yields no content; leave the file untouched
        // rather than overwriting it with nothing.
        if (content != null) {
          merged[relative] = _restoreLineEndings((
            text: content,
            lineEnding: ours.lineEnding,
          ));
        }
      }

      for (final relative in _walk(baseDir)) {
        if (File(p.join(theirsDir.path, relative)).existsSync()) continue;
        if (!File(p.join(projectDir.path, relative)).existsSync()) continue;
        results[relative] = UpgradeStatus.removedUpstream;
      }
    } finally {
      // Two whole reconstructed app trees live in here — four when the
      // addon replay falls back — and nothing past this point reads them.
      // Every run, dry ones included, used to leave them behind, so the
      // temp volume grew by a template per invocation.
      try {
        work.deleteSync(recursive: true);
      } on FileSystemException {
        // Temp cleanup best-effort.
      }
    }

    _report(
      from,
      results,
      upToDate: upToDate,
      localEdits: localEdits,
      apply: apply,
    );

    if (apply) {
      // Conflicted files are written last. A tree left half-way through
      // this loop can still be re-merged — a file already carrying the
      // new content matches THEIRS and reports as up to date — but a file
      // carrying conflict markers cannot: re-merging one writes markers
      // into markers (#166). Writing them last means the write failures
      // that actually happen (a read-only file, an editor or antivirus
      // holding one open, a full disk) leave none behind.
      final writeOrder = [
        ...results.keys.where((e) => results[e] != UpgradeStatus.conflict),
        ...results.keys.where((e) => results[e] == UpgradeStatus.conflict),
      ];
      for (final relative in writeOrder) {
        final content = merged[relative];
        if (content == null) continue; // removedUpstream: never delete.
        try {
          File(p.join(projectDir.path, relative))
            ..parent.createSync(recursive: true)
            ..writeAsStringSync(content);
        } on FileSystemException catch (error) {
          // Deliberately records nothing. .fluframe.json still names
          // $from, so the re-run merges the same BASE and picks up
          // exactly the files this loop never reached; recording the
          // version — or a pendingUpgrade, which resolves into recording
          // the version — would claim an upgrade the tree does not have,
          // and the `from == cliVersion` short-circuit would then seal
          // the missing files out for good. Without this the failure
          // escaped as "This is a bug" plus a stack trace, having left
          // the tree half-upgraded and unrecorded either way.
          _log
            ..writeln()
            ..writeln(
              'Could not write $relative: '
              '${error.osError?.message ?? error.message}',
            )
            ..writeln(
              'The upgrade stopped there, so the app is part-way through '
              'it. Nothing was recorded — .fluframe.json still says '
              '$from — so once whatever blocked the write is cleared, '
              're-running fluframe upgrade --apply finishes the rest. To '
              'start over instead, restore the tree from git first.',
            );
          return ExitCode.software.code;
        }
      }
      final conflicts = results.values
          .where((status) => status == UpgradeStatus.conflict)
          .length;
      // Record the new version only once the tree actually matches it.
      // Otherwise the `from == cliVersion` short-circuit above locks the
      // user out of re-running after they resolve the markers, and the
      // only way back is hand-editing .fluframe.json.
      if (conflicts == 0) {
        meta = {...meta, 'cliVersion': cliVersion}
          ..remove(_pendingVersionKey)
          ..remove(_pendingFilesKey);
        metaFile.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(meta)}\n',
        );
      } else {
        // The upgrade is half-done: the tree carries this version's
        // changes plus markers the user has to settle. Record that, so the
        // re-run can finish it instead of merging the same BASE again and
        // writing markers back into the file they just resolved (#166).
        meta = {
          ...meta,
          // A --from app has no cliVersion; recording the one it is AT
          // keeps the file self-describing, and keeps the message below
          // true for it (#178).
          if (meta['cliVersion'] == null) 'cliVersion': from,
          _pendingVersionKey: cliVersion,
          _pendingFilesKey: results.entries
              .where((e) => e.value == UpgradeStatus.conflict)
              .map((e) => e.key)
              .toList(),
        };
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
      final decoded = jsonDecode(file.readAsStringSync());
      // A bundle holding a JSON array here met a bare `as` cast and threw
      // a TypeError, which is an Error — not the FormatException this
      // catch promises to fall back on, so the fallback below never ran
      // and a data problem in a downloaded bundle surfaced as a crash
      // (#187). The decoder's own fields are guarded the same way.
      if (decoded is! Map<String, Object?>) {
        throw FormatException(
          'the addon registry is a ${decoded.runtimeType}, not an object',
        );
      }
      return decodeAddonRegistry(decoded);
    } on FormatException catch (error) {
      _log.writeln(
        'Ignoring ${file.path}: ${error.message}. Falling back to this '
        "version's addon definitions.",
      );
      return null;
    }
  }

  /// Whether [a] is a strictly newer semantic version than [b].
  static bool _isNewer(SemVer a, SemVer b) {
    if (a.major != b.major) return a.major > b.major;
    if (a.minor != b.minor) return a.minor > b.minor;
    return a.patch > b.patch;
  }

  /// The `name:` declared in [projectDir]'s pubspec.yaml, or `null`.
  static String? _packageNameFromPubspec(Directory projectDir) {
    final pubspec = File(p.join(projectDir.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    final match = RegExp(
      r'^name:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    return match?.group(1);
  }

  /// A whole `major.minor.patch`, with the optional pre-release and build
  /// suffixes pub.dev accepts — and nothing else.
  ///
  /// Anchored at both ends, which is the entire point: [parseSemVer] is
  /// unanchored by design, so it cannot decide whether a string IS a
  /// version, only whether one appears inside it. The suffix charset is
  /// semver's own, which holds no `/` and no `%`, so a value that matches
  /// this cannot add a path segment to the bundle URL it is spliced into.
  static final RegExp _versionPattern = RegExp(
    r'^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$',
  );

  /// Metadata key holding the version an interrupted upgrade was heading
  /// for. Present only between a conflicted `--apply` and its follow-up.
  static const String _pendingVersionKey = 'pendingUpgrade';

  /// Metadata key holding the files that `--apply` left marked.
  static const String _pendingFilesKey = 'pendingConflicts';

  /// Of the files an interrupted upgrade marked, those still carrying
  /// markers.
  ///
  /// Only the recorded files are checked, never the whole tree: a user can
  /// have a git merge of their own in flight, and that is none of this
  /// command's business. A recorded file that has since been deleted counts
  /// as resolved.
  static List<String> _stillConflicted(
    Directory projectDir,
    Map<String, dynamic> meta,
  ) {
    final recorded = (meta[_pendingFilesKey] as List<dynamic>? ?? const [])
        .cast<String>();
    return [
      for (final relative in recorded)
        if (_hasConflictMarkers(File(p.join(projectDir.path, relative))))
          relative,
    ];
  }

  /// Whether [relative] stays inside the project it is joined onto.
  ///
  /// Both separators are rejected whatever the host is, as in
  /// [AddonPatch.fromJson]: a `.fluframe.json` written on Windows must
  /// not decode cleanly on Linux and travel on from there.
  static bool _isProjectRelative(String relative) {
    final normalized = p.posix.normalize(relative.replaceAll(r'\', '/'));
    return !p.posix.isAbsolute(normalized) &&
        !p.windows.isAbsolute(relative) &&
        normalized != '..' &&
        !normalized.startsWith('../');
  }

  static bool _hasConflictMarkers(File file) {
    if (!file.existsSync()) return false;
    try {
      return file.readAsStringSync().contains('<<<<<<<');
    } on FileSystemException {
      return false;
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

  /// Reads [file] as one side of a merge, or `null` when it holds no
  /// UTF-8 text — see [UpgradeStatus.unreadable].
  _Loaded? _load(File file) {
    final String raw;
    try {
      raw = file.readAsStringSync();
    } on FileSystemException {
      // dart:io wraps a UTF-8 decode failure in a FileSystemException;
      // FormatException is what the decoder itself throws, so catch both
      // rather than depend on which layer surfaces it.
      return null;
    } on FormatException {
      return null;
    }
    // First terminator wins: a stray CRLF in an otherwise LF file should
    // not flip the whole file over on write.
    final newline = raw.indexOf('\n');
    final crlf = newline > 0 && raw.codeUnitAt(newline - 1) == 0x0d;
    return (
      text: raw.replaceAll('\r\n', '\n'),
      lineEnding: crlf ? '\r\n' : '\n',
    );
  }

  /// Puts [file]'s own line terminators back into its normalized text.
  ///
  /// Everything is compared and merged as LF, but writing LF back into a
  /// file the user keeps as CRLF rewrites every line of it — one merged
  /// hunk turns into a whole-file diff in their next commit.
  String _restoreLineEndings(_Loaded file) => file.lineEnding == '\n'
      ? file.text
      : file.text.replaceAll('\n', file.lineEnding);

  /// Prints the per-file report.
  ///
  /// [upToDate] and [localEdits] cover the files that produced no result
  /// row: the user's copy already matches the current template, or it
  /// differs from a template that did not change, so the upgrade leaves
  /// it alone.
  void _report(
    String from,
    Map<String, UpgradeStatus> results, {
    required int upToDate,
    required int localEdits,
    required bool apply,
  }) {
    final counts = <UpgradeStatus, int>{};
    for (final status in results.values) {
      counts[status] = (counts[status] ?? 0) + 1;
    }
    final summary = [
      'up to date: $upToDate',
      'your edits kept: $localEdits',
      'added: ${counts[UpgradeStatus.added] ?? 0}',
      'merged: ${counts[UpgradeStatus.cleanMerge] ?? 0}',
      'conflicts: ${counts[UpgradeStatus.conflict] ?? 0}',
      'removed upstream: ${counts[UpgradeStatus.removedUpstream] ?? 0}',
      if (counts[UpgradeStatus.deletedLocally] != null)
        'deleted locally: ${counts[UpgradeStatus.deletedLocally]}',
      if (counts[UpgradeStatus.unreadable] != null)
        'unreadable: ${counts[UpgradeStatus.unreadable]}',
    ];
    // nightly.yml greps this literal: .github/workflows/nightly.yml, job
    // upgrade-canary, `grep -qF "Upgrade $FROM -> $CURRENT (dry run)"`.
    // Reaching this line is that job's proof the published archive was
    // fetched, checked against pub.dev's archive_sha256 and unpacked into
    // a merge base — the check itself prints nothing on the happy path.
    // Reword it and the nightly goes red with a log naming neither the
    // string nor the workflow — upgrader_test.dart pins it so the break
    // lands here instead.
    _log
      ..writeln()
      ..writeln(
        'Upgrade $from -> $cliVersion (${apply ? 'apply' : 'dry run'})',
      )
      ..writeln('  ${summary.join('   ')}');
    final labels = {
      UpgradeStatus.added: '+',
      UpgradeStatus.cleanMerge: '~',
      UpgradeStatus.conflict: '!',
      UpgradeStatus.removedUpstream: '-',
      UpgradeStatus.deletedLocally: '-',
      UpgradeStatus.unreadable: '?',
    };
    for (final entry in results.entries) {
      final suffix = switch (entry.value) {
        UpgradeStatus.conflict => ' (CONFLICT)',
        UpgradeStatus.removedUpstream => ' (removed upstream - kept)',
        UpgradeStatus.deletedLocally => ' (deleted locally - not restored)',
        UpgradeStatus.unreadable => ' (not UTF-8 text - skipped)',
        _ => '',
      };
      _log.writeln('  ${labels[entry.value]} ${entry.key}$suffix');
    }
    if (results.isEmpty) {
      _log.writeln(
        localEdits == 0
            ? '  Nothing to change — the app already matches.'
            : '  Nothing to change — this template update does not touch '
                  'the $localEdits file(s) you edited.',
      );
    }
  }
}
