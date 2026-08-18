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

    test('keeps a wrapped directive whole when sorting moves it', () {
      // `dart format` breaks a combinator onto its own line once the
      // directive passes 80 columns, and that line does not start with
      // `import `. Sorting line by line flushed the run at it, so the
      // head sorted into place and the orphaned combinator was re-emitted
      // after it — a file that does not parse, written into every
      // generated app the moment one template import gets long enough.
      const source = '''
import 'package:zzz/z.dart';
import 'package:aaa/a.dart'
    show Thing;

void main() {}
''';

      expect(sortImports(source), '''
import 'package:aaa/a.dart'
    show Thing;
import 'package:zzz/z.dart';

void main() {}
''');
    });

    test('carries every continuation line of a wrapped directive', () {
      // The directive ends at the `;`, not at the first line that is not
      // an import, so a second combinator line travels with it too.
      const source = '''
import 'package:zzz/z.dart';
import 'package:aaa/a.dart'
    show Thing
    hide Other;
''';

      expect(sortImports(source), '''
import 'package:aaa/a.dart'
    show Thing
    hide Other;
import 'package:zzz/z.dart';
''');
    });

    test('is idempotent over a wrapped directive', () {
      const source = '''
import 'package:b/b.dart'
    as b;
import 'package:a/a.dart';
''';

      final once = sortImports(source);

      expect(once, '''
import 'package:a/a.dart';
import 'package:b/b.dart'
    as b;
''');
      expect(sortImports(once), once);
    });
  });
}
