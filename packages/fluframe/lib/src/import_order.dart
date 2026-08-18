/// Sorting a Dart file's import directives the way `dart fix --apply`
/// does under `directives_ordering`.
///
/// The overlay renames `fluframe_app` to the project's own package name,
/// and that changes where those imports sort — `demo_app` sorts before
/// `dio`, `my_app` sorts after `flutter`. `create` used to repair this by
/// shelling out to `dart fix --apply` afterwards, which meant the sorted
/// result existed only on the `create` path: the bare overlay the
/// upgrader builds its merge base from kept the template's order, so
/// every file whose imports moved looked like the user had edited it
/// (#165). Sorting here instead makes both paths produce the same bytes,
/// and leaves `dart fix` nothing to do.
library;

/// Sorts each run of consecutive `import` directives in [source].
///
/// Runs are sorted independently rather than merged, which preserves the
/// blank line the template keeps between its `dart:` imports and its
/// `package:` imports — `dart fix` preserves it too.
///
/// A directive runs until the line that closes it with `;`, so a wrapped
/// one moves as a unit. `dart format` puts a combinator on its own line
/// once a directive passes 80 columns, and sorting line by line then cut
/// the head off its tail: the run flushed at the continuation, so the
/// head was sorted into place and the orphaned `    show X;` re-emitted
/// after it. That is a file that does not parse, and this runs over every
/// template file on the `create` path — one long import name away from
/// shipping in every generated app.
///
/// Files carrying `// ignore_for_file: type=lint` are returned untouched:
/// the analyzer skips them, so `dart fix` does not reorder them either,
/// and the generated `lib/l10n/gen/` sources are exactly that case.
///
/// Verified against a real `fluframe create my_app` (a name that sorts
/// after `flutter`, so 25 files move): applying this to the bare overlay
/// reproduces the `dart fix --apply` output byte for byte in all 43
/// files.
String sortImports(String source) {
  if (source.contains('ignore_for_file: type=lint')) return source;

  final lines = source.split('\n');
  final out = <String>[];
  // One entry per directive: its `import ...` head line, followed by any
  // continuation lines the directive wrapped onto.
  final run = <List<String>>[];
  List<String>? wrapped;

  void flush() {
    if (run.isEmpty) return;
    // The head line carries the URI, which is what the ordering is about;
    // the continuation lines follow it wherever it lands.
    run.sort((a, b) => a.first.compareTo(b.first));
    out.addAll(run.expand((directive) => directive));
    run.clear();
  }

  bool closesDirective(String line) => line.trimRight().endsWith(';');

  for (final line in lines) {
    if (wrapped != null) {
      wrapped.add(line);
      if (closesDirective(line)) {
        run.add(wrapped);
        wrapped = null;
      }
      continue;
    }
    if (line.startsWith('import ')) {
      if (closesDirective(line)) {
        run.add([line]);
      } else {
        wrapped = [line];
      }
      continue;
    }
    flush();
    out.add(line);
  }
  // A directive left open at end of file is not something `dart format`
  // can produce, but dropping its head would be a worse answer than
  // emitting it where it was found.
  if (wrapped != null) run.add(wrapped);
  flush();

  return out.join('\n');
}
