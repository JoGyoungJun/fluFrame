// Copies the overlay subset of the monorepo's /template into templates/app
// so it ships inside the published package.
//
// Run from the package root before publishing:
//   dart run tool/sync_template.dart
//   dart pub publish --dry-run
import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/bundle_hygiene.dart';
import 'package:fluframe/src/project_generator.dart';
import 'package:path/path.dart' as p;

void main() {
  final packageRoot = Directory.current;
  final repoTemplate = Directory(
    p.normalize(p.join(packageRoot.path, '..', '..', 'template')),
  );
  if (!repoTemplate.existsSync()) {
    stderr.writeln('Repo template not found at ${repoTemplate.path}.');
    exitCode = 1;
    return;
  }

  // What must never reach templates/, sourced from the project's own rules
  // rather than a second list that can drift: template/.gitignore documents
  // env/*.local.json as where real secrets go. bundleSecretPatterns adds the
  // shapes a Flutter .gitignore has no reason to mention (.env, keys).
  final templateGitignore = File(p.join(repoTemplate.path, '.gitignore'));
  if (!templateGitignore.existsSync()) {
    // Without it the sync would silently lose its only secret filter.
    stderr.writeln('template/.gitignore not found — refusing to sync.');
    exitCode = 1;
    return;
  }

  // Backend addon sources (ADR 0001) ship alongside the base template.
  final repoAddons = Directory(
    p.normalize(p.join(packageRoot.path, '..', '..', 'template_addons')),
  );

  // Completeness is a gate, not a log line. A missing overlay entry used to
  // warn and exit 0, and a missing template_addons/ was skipped in silence
  // while templates/addons.json — written unconditionally below — still
  // described its addons. ADR 0002 makes every published bundle the
  // permanent merge base for `fluframe upgrade`, and a pub.dev version can
  // never be replaced, so an incomplete bundle stays broken for every app
  // generated from it. Checked before anything is written: refusing beats
  // leaving a half-built bundle on disk for the next step to publish.
  final missingSources = findMissingBundleSources(
    templateRoot: repoTemplate,
    entries: overlayEntries,
    addonRoot: repoAddons,
  );
  if (missingSources.isNotEmpty) {
    stderr.writeln(
      'MISSING BUNDLE SOURCES — refusing to build an incomplete bundle:\n'
      '${missingSources.map((path) => '  $path').join('\n')}',
    );
    exitCode = 1;
    return;
  }

  final excluded = _BundleFilter(
    GitignoreMatcher.parse(templateGitignore.readAsStringSync()),
    GitignoreMatcher.parse(bundleSecretPatterns),
  );

  final bundleRoot = Directory(p.join(packageRoot.path, 'templates', 'app'));
  if (bundleRoot.existsSync()) {
    bundleRoot.deleteSync(recursive: true);
  }
  bundleRoot.createSync(recursive: true);

  var copied = 0;
  for (final entry in overlayEntries) {
    final source = p.join(repoTemplate.path, entry);
    // Dot-prefixed entries ship under the dot-less name the CLI overlay
    // restores — see bundledOverlayNames for why, and edit it there so the
    // two sides cannot disagree about a spelling.
    final destName = bundledOverlayNames[entry] ?? entry;
    final destination = p.join(bundleRoot.path, destName);
    if (FileSystemEntity.isDirectorySync(source)) {
      if (excluded.rejects(entry, isDirectory: true)) continue;
      _copyDirectory(
        Directory(source),
        Directory(destination),
        excluded,
        relativeRoot: entry,
      );
      copied++;
    } else if (FileSystemEntity.isFileSync(source)) {
      if (excluded.rejects(entry)) continue;
      File(source).copySync(destination);
      copied++;
    } else {
      // Unreachable after the gate above unless the source vanished
      // mid-run; still a failed publish rather than a warning nobody sees.
      stderr.writeln('Template entry "$entry" vanished during the sync.');
      exitCode = 1;
    }
  }

  // The gate above already refused a missing template_addons/, so this no
  // longer has an "or do nothing" branch to fall through silently.
  final addonBundle = Directory(
    p.join(packageRoot.path, 'templates', 'addons'),
  );
  if (addonBundle.existsSync()) {
    addonBundle.deleteSync(recursive: true);
  }
  _copyDirectory(repoAddons, addonBundle, excluded, relativeRoot: '');
  stdout.writeln('Synced template_addons into templates/addons.');

  // Ship the addon patch definitions WITH the bundle. `fluframe upgrade`
  // rebuilds the merge base from the bundle of the version an app was
  // generated with, and patch anchors are exact strings from that era's
  // template — so a future CLI must read these, not its own.
  File(p.join(packageRoot.path, 'templates', addonRegistryFileName))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(encodeAddonRegistry())}\n',
    );

  // The tally is what was actually copied, not overlayEntries.length:
  // printing the intended number unconditionally made a skipped entry
  // invisible in the log as well as in the exit code.
  stdout
    ..writeln('Wrote templates/$addonRegistryFileName.')
    ..writeln(
      'Synced $copied of ${overlayEntries.length} entries into '
      'templates/app.',
    );
  excluded.report(stdout);

  // Belt and braces: the filter above is what should have kept the bundle
  // clean, so this re-reads the result rather than trusting it. A hit here
  // means the filter has a hole, and the only safe outcome is a non-zero
  // exit — publish.bat runs this before uploading.
  final leaks = reportBundleLeaks(
    Directory(p.join(packageRoot.path, 'templates')),
    stderr,
  );
  // Assigned, never lowered: an entry that vanished mid-sync already set
  // this, and a clean secret scan must not undo that.
  if (leaks != 0) exitCode = 1;
}

/// The union of the two exclusion sources, remembering what it rejected so
/// the sync can say so out loud instead of silently shrinking the bundle.
class _BundleFilter {
  _BundleFilter(this._gitignore, this._secrets);

  final GitignoreMatcher _gitignore;
  final GitignoreMatcher _secrets;
  final List<String> _skippedSecrets = [];
  final List<String> _skippedIgnored = [];

  bool rejects(String relativePath, {bool isDirectory = false}) {
    if (_secrets.ignores(relativePath, isDirectory: isDirectory)) {
      _skippedSecrets.add(relativePath);
      return true;
    }
    if (_gitignore.ignores(relativePath, isDirectory: isDirectory)) {
      _skippedIgnored.add(relativePath);
      return true;
    }
    return false;
  }

  void report(StringSink out) {
    if (_skippedIgnored.isNotEmpty) {
      out.writeln(
        'Skipped ${_skippedIgnored.length} path(s) ignored by '
        'template/.gitignore: ${_skippedIgnored.join(', ')}',
      );
    }
    for (final path in _skippedSecrets) {
      // Named individually and loudly: this is the case the guard exists
      // for, and a maintainer should see which of their local files it was.
      out.writeln('EXCLUDED (secret-like, never published): $path');
    }
  }
}

void _copyDirectory(
  Directory source,
  Directory destination,
  _BundleFilter excluded, {
  required String relativeRoot,
}) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final name = p.basename(entity.path);
    // Paths are matched relative to the template root, because that is what
    // template/.gitignore's anchored patterns (`env/*.local.json`) mean.
    final relative = relativeRoot.isEmpty ? name : '$relativeRoot/$name';
    final target = p.join(destination.path, name);
    if (entity is Directory) {
      if (excluded.rejects(relative, isDirectory: true)) continue;
      _copyDirectory(
        entity,
        Directory(target),
        excluded,
        relativeRoot: relative,
      );
    } else if (entity is File) {
      if (excluded.rejects(relative)) continue;
      entity.copySync(target);
    }
  }
}
