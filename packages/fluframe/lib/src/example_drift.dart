/// Comparing `examples/` against the `template/` they were generated from.
///
/// The examples are generated apps that were then extended, so they share
/// most of their source with the template. Nothing compared them, and they
/// rotted: both were missing `core/logging/error_handlers.dart` entirely —
/// the file the template calls its crash-reporting seam.
library;

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
  // Strings for those features live alongside the shared ones. The ARBs are
  // still checked key-by-key below — the exemption is for the file, not for
  // its contents.
  'lib/l10n/',
  // The example's own README describes the example, not the template.
  'README.md',
  'pubspec.yaml',
];

/// Shared ARB keys an example is allowed to give a different value.
///
/// Keyed by example directory name. **Empty on purpose.** A shared key is
/// one the template also defines, so after the rename tokens are applied
/// the values should match; a difference is drift until someone writes down
/// why it is not. Translating a shared string differently is the case this
/// exists for — and the fixer never overwrites a value, so an entry here
/// only silences the report.
const Map<String, Set<String>> allowedValueDivergence = {};

/// Outcome of one drift check.
typedef DriftResult = ({int drifted, int keysAdded});

/// Compares every example under [examples] against [template].
///
/// Reports to [out]. With [fix], re-copies shared files and inserts ARB keys
/// the example is missing — never removing or overwriting what it already
/// has. Returns the counts; the caller decides the exit code.
DriftResult checkExampleDrift({
  required Directory template,
  required Directory examples,
  required bool fix,
  required StringSink out,
}) {
  var drifted = 0;
  var keysAdded = 0;

  for (final example in examples.listSync().whereType<Directory>()) {
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
      out.writeln(
        '${actual.existsSync() ? 'differs' : 'missing'}: $name/$relative',
      );
      if (fix) {
        actual
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(expected);
      }
    }
  }

  // lib/l10n is exempt above because each example adds its own strings — but
  // it may never DROP one, or a shared screen renders a missing key. That is
  // exactly how both examples ended up on en+ko while the shared settings
  // screen offered a Japanese chip.
  for (final example in examples.listSync().whereType<Directory>()) {
    final result = _checkStrings(template, example, fix: fix, out: out);
    drifted += result.drifted;
    keysAdded += result.keysAdded;
  }

  return (drifted: drifted, keysAdded: keysAdded);
}

/// Checks (and with [fix], repairs) one example's ARB files.
DriftResult _checkStrings(
  Directory template,
  Directory example, {
  required bool fix,
  required StringSink out,
}) {
  final name = p.basename(example.path);
  var drifted = 0;
  var keysAdded = 0;

  final locales =
      Directory(p.join(template.path, 'lib', 'l10n'))
          .listSync()
          .whereType<File>()
          .where((file) => p.extension(file.path) == '.arb')
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final source in locales) {
    final file = p.basename(source.path);
    final relative = 'lib/l10n/$file';
    final target = File(p.join(example.path, 'lib', 'l10n', file));

    // The template's values still carry the rename tokens, so compare and
    // insert what the example WOULD have been generated with. The shared
    // file loop above already rewrites; doing it here too is what keeps
    // `appTitle` from being reported as drift in every example forever.
    final expected =
        jsonDecode(
              rewriteTemplateContent(
                source.readAsStringSync(),
                projectName: name,
              ),
            )
            as Map<String, Object?>;

    if (!target.existsSync()) {
      drifted++;
      out.writeln('missing locale: $name/$relative');
      if (fix) {
        target
          ..parent.createSync(recursive: true)
          ..writeAsStringSync(_encodeArb(expected));
        keysAdded += _messageKeys(expected).length;
      }
      continue;
    }

    final actual =
        jsonDecode(target.readAsStringSync()) as Map<String, Object?>;
    final merged = Map<String, Object?>.of(actual);
    var changed = false;

    for (final key in _messageKeys(expected)) {
      if (!actual.containsKey(key)) {
        drifted++;
        out.writeln('missing string: $name/$file -> $key');
        if (fix) {
          merged[key] = expected[key];
          // Carry the `@key` block across with its key. Only the English
          // ARB has them, so this is a no-op for the translations.
          final meta = '@$key';
          if (expected.containsKey(meta)) merged[meta] = expected[meta];
          changed = true;
          keysAdded++;
        }
        continue;
      }

      // Present in both. A different value is reported and left alone: the
      // example may have translated it, and overwriting a translation is
      // worse than the drift.
      if (allowedValueDivergence[name]?.contains(key) ?? false) continue;
      if (actual[key] != expected[key]) {
        drifted++;
        out.writeln(
          'differing string: $name/$file -> $key\n'
          '    template: ${_preview(expected[key])}\n'
          '    example:  ${_preview(actual[key])}',
        );
      }
    }

    if (fix && changed) target.writeAsStringSync(_encodeArb(merged));
  }

  return (drifted: drifted, keysAdded: keysAdded);
}

/// Message keys (everything except `@`-prefixed metadata), in file order.
Iterable<String> _messageKeys(Map<String, Object?> arb) =>
    arb.keys.where((key) => !key.startsWith('@'));

String _encodeArb(Map<String, Object?> arb) =>
    '${const JsonEncoder.withIndent('  ').convert(arb)}\n';

String _preview(Object? value) {
  final text = '$value';
  return text.length <= 60 ? text : '${text.substring(0, 57)}...';
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
