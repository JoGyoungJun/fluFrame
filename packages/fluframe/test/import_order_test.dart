import 'package:fluframe/src/import_order.dart';
import 'package:test/test.dart';

void main() {
  group('sortImports', () {
    test('sorts a package import block', () {
      const source = '''
import 'package:my_app/app/app.dart';
import 'package:flutter/material.dart';

void main() {}
''';

      expect(sortImports(source), '''
import 'package:flutter/material.dart';
import 'package:my_app/app/app.dart';

void main() {}
''');
    });

    test('keeps dart: and package: as separate runs', () {
      // The template puts a blank line between them and `dart fix` keeps
      // it, so the runs are sorted independently rather than merged.
      const source = '''
import 'dart:async';

import 'package:my_app/a.dart';
import 'package:flutter/material.dart';
''';

      expect(sortImports(source), '''
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_app/a.dart';
''');
    });

    test('leaves a file the analyzer skips alone', () {
      // lib/l10n/gen/* carries this, and `dart fix` does not touch it —
      // sorting it would make the overlay disagree with `create`.
      const source = '''
// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint
''';

      expect(sortImports(source), source);
    });

    test('is idempotent', () {
      const source = '''
import 'package:b/b.dart';
import 'package:a/a.dart';
''';
      final once = sortImports(source);

      expect(sortImports(once), once);
    });

    test('leaves a file with no imports untouched', () {
      const source = 'const answer = 42;\n';

      expect(sortImports(source), source);
    });

    test('does not move code that follows the imports', () {
      const source = '''
import 'package:b/b.dart';
import 'package:a/a.dart';
const x = 1;
import 'package:c/c.dart';
''';

      // The trailing directive is its own run: sorting must not hoist it
      // above the declaration between them.
      expect(sortImports(source), '''
import 'package:a/a.dart';
import 'package:b/b.dart';
const x = 1;
import 'package:c/c.dart';
''');
    });
  });
}
