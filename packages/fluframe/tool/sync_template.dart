// Copies the overlay subset of the monorepo's /template into templates/app
// so it ships inside the published package.
//
// Run from the package root before publishing:
//   dart run tool/sync_template.dart
//   dart pub publish --dry-run
import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';
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

  final bundleRoot = Directory(p.join(packageRoot.path, 'templates', 'app'));
  if (bundleRoot.existsSync()) {
    bundleRoot.deleteSync(recursive: true);
  }
  bundleRoot.createSync(recursive: true);

  for (final entry in overlayEntries) {
    final source = p.join(repoTemplate.path, entry);
    // Dot-prefixed entries ship under the dot-less name the CLI overlay
    // restores — see bundledOverlayNames for why, and edit it there so the
    // two sides cannot disagree about a spelling.
    final destName = bundledOverlayNames[entry] ?? entry;
    final destination = p.join(bundleRoot.path, destName);
    if (FileSystemEntity.isDirectorySync(source)) {
      _copyDirectory(Directory(source), Directory(destination));
    } else if (FileSystemEntity.isFileSync(source)) {
      File(source).copySync(destination);
    } else {
      stderr.writeln('Warning: template entry "$entry" not found, skipped.');
    }
  }

  // Backend addon sources (ADR 0001) ship alongside the base template.
  final repoAddons = Directory(
    p.normalize(p.join(packageRoot.path, '..', '..', 'template_addons')),
  );
  if (repoAddons.existsSync()) {
    final addonBundle = Directory(
      p.join(packageRoot.path, 'templates', 'addons'),
    );
    if (addonBundle.existsSync()) {
      addonBundle.deleteSync(recursive: true);
    }
    _copyDirectory(repoAddons, addonBundle);
    stdout.writeln('Synced template_addons into templates/addons.');
  }

  // Ship the addon patch definitions WITH the bundle. `fluframe upgrade`
  // rebuilds the merge base from the bundle of the version an app was
  // generated with, and patch anchors are exact strings from that era's
  // template — so a future CLI must read these, not its own.
  File(p.join(packageRoot.path, 'templates', addonRegistryFileName))
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(encodeAddonRegistry())}\n',
    );

  stdout
    ..writeln('Wrote templates/$addonRegistryFileName.')
    ..writeln('Synced ${overlayEntries.length} entries into templates/app.');
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final target = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      _copyDirectory(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}
