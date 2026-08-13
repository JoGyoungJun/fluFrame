// Reports where examples/ has drifted from template/.
//
// The comparison itself lives in lib/src/example_drift.dart so it can be
// unit-tested against temp directories instead of the real checkout.
//
// Run from the package root:
//   dart run tool/check_example_drift.dart          # report + exit 1 on drift
//   dart run tool/check_example_drift.dart --fix    # re-sync what it can
import 'dart:io';

import 'package:fluframe/src/example_drift.dart';
import 'package:path/path.dart' as p;

void main(List<String> arguments) {
  final fix = arguments.contains('--fix');
  final root = Directory.current.path;
  final template = Directory(p.normalize(p.join(root, '..', '..', 'template')));
  final examples = Directory(
    p.normalize(p.join(root, '..', '..', 'examples')),
  );
  if (!template.existsSync() || !examples.existsSync()) {
    stderr.writeln('Run this from packages/fluframe in a full checkout.');
    exitCode = 1;
    return;
  }

  final result = checkExampleDrift(
    template: template,
    examples: examples,
    fix: fix,
    out: stdout,
  );

  if (result.drifted == 0) {
    stdout.writeln('Examples match the template.');
    return;
  }

  if (fix) {
    final keys = result.keysAdded;
    stdout
      ..writeln(
        '\nRewrote ${result.drifted} file(s)'
        '${keys == 0 ? '' : ' and added $keys ARB key(s)'}. '
        'In each example now run:\n'
        '  flutter pub get && dart fix --apply && flutter gen-l10n\n'
        '  flutter analyze && flutter test\n'
        "`dart fix` is not optional: the copies carry the TEMPLATE's import "
        'order, and directives_ordering is fatal here.',
      )
      ..writeln(
        keys == 0
            ? ''
            : '`flutter gen-l10n` is not optional either: the new ARB keys '
                  'have no generated getters yet.',
      )
      ..writeln(
        'Any `differing string:` above is NOT fixed — a value present in '
        'both may be a deliberate translation, so it is reported and left '
        'alone. Fix it by hand, or record it in allowedValueDivergence in '
        'lib/src/example_drift.dart with a reason.',
      );
    return;
  }

  stdout.writeln(
    '\n${result.drifted} difference(s) from template/. Re-sync with:\n'
    '  dart run tool/check_example_drift.dart --fix\n'
    'or, if the difference is deliberate, add the path to '
    'intentionallyDivergent (or the key to allowedValueDivergence) in '
    'lib/src/example_drift.dart with a reason.',
  );
  exitCode = 1;
}
