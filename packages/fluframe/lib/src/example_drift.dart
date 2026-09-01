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
///
/// Only paths under `lib/` and `test/` belong here — those two are the
/// whole of what [_sharedFiles] walks. A root file such as `README.md` or
/// `pubspec.yaml` is outside the byte comparison to begin with, so listing
/// it exempts nothing and reads as protection that is not there. What
/// gates `pubspec.yaml` instead is the dependency-block comparison in
/// [_checkPubspec]: the example owns its name and description, but not
/// the versions it pins.
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

/// Packages an example is allowed to declare differently from the
/// template — or to declare at all, when the template does not.
///
/// Keyed by example directory name, holding package names (and `sdk`, the
/// one entry of the `environment:` block). **Empty on purpose.** An
/// example is a generated app plus a feature, so every pin it shares with
/// the template is the template's to move; a pin that differs is drift
/// until someone writes down why it is not. The two cases this exists
/// for are a package only the example needs — geolocation for the weather
/// example, say — and a shared package the example must hold back for a
/// reason worth a comment.
const Map<String, Set<String>> allowedDependencyDivergence = {};

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

  // pubspec.yaml is outside the byte comparison — the example owns its
  // name and description — but the versions it pins are not its own. The
  // examples are what the README points a reader at, and they sat a minor
  // version behind the template on go_router with nothing to say so.
  for (final example in examples.listSync().whereType<Directory>()) {
    drifted += _checkPubspec(template, example, out: out);
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

/// Compares one example's `environment:`, `dependencies:` and
/// `dev_dependencies:` blocks against the template's.
///
/// Reported, never rewritten — a version bump has to be resolved and
/// locked (`flutter pub get`) in the same change, and a fixer that edited
/// the pubspec would leave `pubspec.lock` describing a resolution that no
/// longer exists.
int _checkPubspec(
  Directory template,
  Directory example, {
  required StringSink out,
}) {
  final name = p.basename(example.path);
  final source = File(p.join(template.path, 'pubspec.yaml'));
  final target = File(p.join(example.path, 'pubspec.yaml'));
  // No template pubspec means there is nothing to compare against, which
  // is the case in unit fixtures that only exercise the file and ARB
  // loops. A missing one on the example side is real: the drift check is
  // running against something that is not a generated app.
  if (!source.existsSync()) return 0;
  if (!target.existsSync()) {
    out.writeln('missing: $name/pubspec.yaml');
    return 1;
  }

  final expected = _dependencyBlocks(source.readAsStringSync());
  final actual = _dependencyBlocks(target.readAsStringSync());
  final exempt = allowedDependencyDivergence[name] ?? const <String>{};
  var drifted = 0;

  for (final block in expected.keys) {
    final ours = actual[block] ?? const <String, String>{};
    for (final entry in expected[block]!.entries) {
      if (exempt.contains(entry.key)) continue;
      final constraint = ours[entry.key];
      if (constraint == null) {
        drifted++;
        out.writeln(
          'missing dependency: $name/pubspec.yaml -> $block: '
          '${entry.key} (${entry.value})',
        );
        continue;
      }
      if (constraint == entry.value) continue;
      drifted++;
      out.writeln(
        'differing dependency: $name/pubspec.yaml -> $block: ${entry.key}\n'
        '    template: ${entry.value}\n'
        '    example:  $constraint',
      );
    }
    for (final entry in ours.entries) {
      if (exempt.contains(entry.key)) continue;
      if (expected[block]!.containsKey(entry.key)) continue;
      drifted++;
      out.writeln(
        'extra dependency: $name/pubspec.yaml -> $block: '
        '${entry.key} (${entry.value})',
      );
    }
  }

  return drifted;
}

/// The `environment:`, `dependencies:` and `dev_dependencies:` entries of
/// [pubspec], as `block -> package -> constraint`.
///
/// Line-based rather than parsed with package:yaml. These three blocks
/// come out of the template generator, so they are flat `  name: value`
/// lines plus the `sdk: flutter` mappings; taking a YAML dependency onto
/// a published CLI to read them would cost every user of the package a
/// transitive dependency for four lines of comparison. The narrowness is
/// the point — a pubspec shaped unlike the template's is a bigger problem
/// than a pin, and shows up as drift here either way.
Map<String, Map<String, String>> _dependencyBlocks(String pubspec) {
  const blocks = ['environment', 'dependencies', 'dev_dependencies'];
  final parsed = {for (final block in blocks) block: <String, String>{}};
  String? current;
  String? entry;

  for (final line in pubspec.replaceAll('\r\n', '\n').split('\n')) {
    final text = line.trim();
    if (text.isEmpty || text.startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      current = blocks.contains(text.split(':').first.trim())
          ? text.split(':').first.trim()
          : null;
      entry = null;
      continue;
    }
    if (current == null) continue;
    final separator = text.indexOf(':');
    if (separator == -1) continue;
    final key = text.substring(0, separator).trim();
    final value = text.substring(separator + 1).trim();
    final indent = line.length - line.trimLeft().length;
    if (indent <= 2) {
      entry = key;
      parsed[current]![key] = value;
    } else if (entry != null) {
      // A nested mapping — `flutter:` followed by `  sdk: flutter`.
      final head = parsed[current]![entry] ?? '';
      parsed[current]![entry] = head.isEmpty
          ? '$key: $value'
          : '$head, $key: $value';
    }
  }

  return parsed;
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
