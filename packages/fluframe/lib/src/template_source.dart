import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

/// Locates the fluFrame app template on disk.
///
/// Resolution order:
/// 1. [explicitPath], when the user passed `--template-dir`.
/// 2. The template bundled with the published package
///    (`<package root>/templates/app`, produced by `tool/sync_template.dart`).
/// 3. The monorepo checkout layout (`<repo root>/template`), so the CLI
///    works when run from source during development.
Future<Directory?> resolveTemplateDirectory({String? explicitPath}) async {
  if (explicitPath != null) {
    final explicit = Directory(explicitPath);
    return explicit.existsSync() ? explicit : null;
  }

  final packageUri = await Isolate.resolvePackageUri(
    Uri.parse('package:fluframe/fluframe.dart'),
  );
  if (packageUri == null) return null;

  final packageRoot = File.fromUri(packageUri).parent.parent;
  final bundled = Directory(p.join(packageRoot.path, 'templates', 'app'));
  if (bundled.existsSync()) return bundled;

  final repoTemplate = Directory(
    p.join(packageRoot.parent.parent.path, 'template'),
  );
  if (repoTemplate.existsSync()) return repoTemplate;

  return null;
}
