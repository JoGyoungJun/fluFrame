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
  final run = <String>[];

  void flush() {
    if (run.isEmpty) return;
    out.addAll(run.toList()..sort());
    run.clear();
  }

  for (final line in lines) {
    if (line.startsWith('import ')) {
      run.add(line);
      continue;
    }
    flush();
    out.add(line);
  }
  flush();

  return out.join('\n');
}
