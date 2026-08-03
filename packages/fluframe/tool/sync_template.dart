// Copies the overlay subset of the monorepo's /template into templates/app
// so it ships inside the published package.
//
// Run from the package root before publishing:
//   dart run tool/sync_template.dart
//   dart pub publish --dry-run
import 'dart:io';

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
    // Store .gitignore dot-less so its rules cannot influence pub's file
    // selection when publishing; the CLI overlay restores the real name.
    final destName = entry == '.gitignore' ? 'gitignore' : entry;
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

  stdout.writeln('Synced ${overlayEntries.length} entries into templates/app.');
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
