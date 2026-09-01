// Copies the overlay subset of the monorepo's /template into templates/app
// so it ships inside the published package.
//
// The sync itself lives in lib/src/template_sync.dart so its refusals can
// be unit-tested against temp directories instead of the real checkout;
// this stays a shim over it, because tool/publish.bat and
// .github/workflows/publish.yml gate on the exit code below.
//
// Run from the package root before publishing:
//   dart run tool/sync_template.dart
//   dart pub publish --dry-run
import 'dart:io';

import 'package:fluframe/src/template_sync.dart';
import 'package:path/path.dart' as p;

void main() {
  final packageRoot = Directory.current;
  exitCode = syncTemplate(
    packageRoot: packageRoot,
    repoRoot: Directory(p.normalize(p.join(packageRoot.path, '..', '..'))),
  );
}
