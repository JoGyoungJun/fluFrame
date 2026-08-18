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

    test('a trailing comment does not swallow the rest of the file', () {
      // `// ignore: implementation_imports` on an import is a routine
      // analyzer-suggested edit, and the line then does not end in `;`.
      // The directive read as wrapped, so the run kept swallowing lines
      // until one happened to close it — `runApp(...)`, in the next
      // function — and that whole region sorted along with the head,
      // landing above the import it is supposed to follow. The result
      // does not parse.
      const source = '''
import 'package:zoo/zoo.dart';
import 'package:apple/a.dart'; // ignore: implementation_imports

void main() {
  runApp(const App());
}
''';

      expect(sortImports(source), '''
import 'package:apple/a.dart'; // ignore: implementation_imports
import 'package:zoo/zoo.dart';

void main() {
  runApp(const App());
}
''');
    });

    test('a trailing comment does not fuse two directives into one', () {
      // Quieter than the case above, and the half nothing else catches:
      // the swallowed region is the next import, so the two travel as one
      // sort unit and the run comes out misordered while still parsing.
      // That is #165 again — the bare overlay stops matching `dart fix`,
      // so every affected file reports to the user as their own edit.
      const source = '''
import 'package:zoo/zoo.dart'; // ignore: implementation_imports
import 'package:apple/a.dart';
''';

      expect(sortImports(source), '''
import 'package:apple/a.dart';
import 'package:zoo/zoo.dart'; // ignore: implementation_imports
''');
    });

    test('is idempotent over a trailing-comment import', () {
      const source = '''
import 'package:b/b.dart';
import 'package:a/a.dart'; // ignore: implementation_imports
''';

      final once = sortImports(source);

      expect(once, '''
import 'package:a/a.dart'; // ignore: implementation_imports
import 'package:b/b.dart';
''');
      expect(sortImports(once), once);
    });
  });
}
