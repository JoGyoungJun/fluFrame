// Reports where examples/ has drifted from template/.
//
// The examples are generated apps that were then extended, so they share
// most of their source with the template. Nothing compared them, and they
// rotted: both were missing core/logging/error_handlers.dart entirely —
// the file the template calls its crash-reporting seam — while
// docs/architecture.md claimed CI "runs them in a matrix so they cannot
// rot". A matrix proves they compile, not that they still match.
//
// Run from the package root:
//   dart run tool/check_example_drift.dart          # report + exit 1 on drift
//   dart run tool/check_example_drift.dart --fix    # copy the template over
import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/project_generator.dart';
import 'package:path/path.dart' as p;

/// Paths (relative to an app root) an example is expected to own.
///
/// Everything else under `lib/` and `test/` must match the template
/// byte-for-byte after the rename tokens are applied. Add to this list
/// only with a reason: each entry is a file the drift check can no longer
/// protect.
const List<String> intentionallyDivergent = [
  // Each example adds its own feature module and wires it into the shell,
  // so its route table and the doc comment above it are genuinely its own.
  // (main.dart is NOT on this list: both examples' copies were byte-equal
  // to the template's, and letting them drift is how they lost the error
  // hooks in the first place.)
  'lib/app/router/app_router.dart',
  // Strings for those features live alongside the shared ones.
  'lib/l10n/',
  // The example's own README describes the example, not the template.
  'README.md',
  'pubspec.yaml',
];

void main(List<String> arguments) {
  final fix = arguments.contains('--fix');
  final root = Directory.current.path;
  final template = Directory(p.normalize(p.join(root, '..', '..', 'template')));
  final examplesDir = Directory(
    p.normalize(p.join(root, '..', '..', 'examples')),
  );
  if (!template.existsSync() || !examplesDir.existsSync()) {
    stderr.writeln('Run this from packages/fluframe in a full checkout.');
    exitCode = 1;
    return;
  }

  var drifted = 0;
  for (final example in examplesDir.listSync().whereType<Directory>()) {
    final name = p.basename(example.path);
    for (final relative in _sharedFiles(template)) {
      if (intentionallyDivergent.any(relative.startsWith)) continue;
      final expected = rewriteTemplateContent(
        File(p.join(template.path, relative)).readAsStringSync(),
        projectName: name,
      );
      final actual = File(p.join(example.path, relative));
      final same =
          actual.existsSync() &&
          _normalize(actual.readAsStringSync()) == _normalize(expected);
      if (same) continue;
      drifted++;
      stdout.writeln(
        '${actual.existsSync() ? 'differs' : 'missing'}: $name/$relative',
      );
      if (fix) {
        actual
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(expected);
      }
    }
  }

  // lib/l10n is excluded above because each example adds its own strings —
  // but it may never DROP one, or a shared screen renders a missing key.
  // That is exactly how both examples ended up on en+ko while the shared
  // settings screen offered a Japanese chip.
  for (final example in examplesDir.listSync().whereType<Directory>()) {
    drifted += _reportMissingStrings(template, example);
  }

  if (drifted == 0) {
    stdout.writeln('Examples match the template.');
    return;
  }
  if (fix) {
    stdout.writeln(
      '\nRewrote $drifted file(s). In each example now run:\n'
      '  flutter pub get && dart fix --apply && flutter gen-l10n\n'
      '  flutter analyze && flutter test\n'
      "`dart fix` is not optional: the copies carry the TEMPLATE's import "
      'order, and directives_ordering is fatal here.',
    );
    return;
  }
  stdout.writeln(
    '\n$drifted file(s) drifted from template/. Re-sync with:\n'
    '  dart run tool/check_example_drift.dart --fix\n'
    'or, if the difference is deliberate, add the path to '
    'intentionallyDivergent in this file with a reason.',
  );
  exitCode = 1;
}

/// Reports every ARB locale or key the example is missing.
int _reportMissingStrings(Directory template, Directory example) {
  final name = p.basename(example.path);
  var missing = 0;
  final locales = Directory(p.join(template.path, 'lib', 'l10n'))
      .listSync()
      .whereType<File>()
      .where((file) => p.extension(file.path) == '.arb');
  for (final source in locales) {
    final relative = p.join('lib', 'l10n', p.basename(source.path));
    final target = File(p.join(example.path, relative));
    if (!target.existsSync()) {
      missing++;
      stdout.writeln('missing locale: $name/${relative.replaceAll(r'\', '/')}');
      continue;
    }
    final expected = _messageKeys(source);
    final actual = _messageKeys(target);
    for (final key in expected.difference(actual)) {
      missing++;
      stdout.writeln(
        'missing string: $name/${p.basename(source.path)} -> $key',
      );
    }
  }
  return missing;
}

/// Message keys in an ARB file, ignoring `@`-prefixed metadata.
Set<String> _messageKeys(File arb) {
  final decoded = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final key in decoded.keys)
      if (!key.startsWith('@')) key,
  };
}

/// Template files an example is expected to carry a copy of.
Iterable<String> _sharedFiles(Directory template) sync* {
  for (final directory in ['lib', 'test']) {
    final root = Directory(p.join(template.path, directory));
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File) continue;
      yield p.relative(entity.path, from: template.path).replaceAll(r'\', '/');
    }
  }
}

/// Reduces a file to what actually counts as drift.
///
/// Line endings are a checkout artefact. Import ORDER is one too: renaming
/// the package changes where its own imports sort (`weather_app` lands
/// before `flutter`, `fluframe_app` after), which is exactly why the CLI
/// runs `dart fix --apply` after generating. Comparing raw text would
/// report every generated app as drifted from day one.
String _normalize(String content) {
  final lines = content.replaceAll('\r\n', '\n').split('\n');
  final directives = <String>[];
  final rest = <String>[];
  for (final line in lines) {
    if (line.startsWith("import '") || line.startsWith("export '")) {
      directives.add(line);
    } else {
      rest.add(line);
    }
  }
  directives.sort();
  return [...directives, ...rest].join('\n');
}
