import 'dart:convert';
import 'dart:io' as io;

import 'package:fluframe/src/package_name.dart';
import 'package:path/path.dart' as p;

/// Anchors the CLI inserts at, added to the template by design spec 003.
///
/// They are plain comments rather than a parsed AST: the alternative is a
/// dependency on `analyzer` for three insertions, and a comment a user can
/// see is easier to keep than a shape they cannot.
const String routesAnchor = '// fluframe:routes';

/// Anchor for tab branches. See [routesAnchor].
const String branchesAnchor = '// fluframe:branches';

/// Anchor for navigation destinations. See [routesAnchor].
const String destinationsAnchor = '// fluframe:destinations';

/// Relative path of the router the scaffold edits.
const String routerPath = 'lib/app/router/app_router.dart';

/// Why a scaffold run cannot proceed.
///
/// Carries a single sentence, because that is what the user needs; the
/// command turns it into stderr plus an exit code.
class FeatureScaffoldException implements Exception {
  /// Creates an exception explaining [message].
  const FeatureScaffoldException(this.message, {this.hint});

  /// One sentence naming what is wrong.
  final String message;

  /// What to do about it, when there is a specific answer.
  final String? hint;

  @override
  String toString() => message;
}

/// One file the scaffold will create.
class PlannedFile {
  /// Creates a planned write of [contents] to [path].
  const PlannedFile(this.path, this.contents);

  /// Path relative to the project root, in POSIX form.
  final String path;

  /// The complete file body.
  final String contents;
}

/// Everything a run will do, computed before anything is written.
class FeaturePlan {
  /// Creates a plan.
  const FeaturePlan({
    required this.files,
    required this.routerContents,
    required this.arbContents,
    required this.untranslated,
  });

  /// New files, in creation order.
  final List<PlannedFile> files;

  /// The rewritten router source.
  final String routerContents;

  /// Rewritten ARB sources, keyed by path relative to the project root.
  final Map<String, String> arbContents;

  /// Keys that landed in a non-English ARB with the English text, as
  /// `path -> keys`.
  final Map<String, List<String>> untranslated;
}

/// Generates a feature module into an existing fluFrame app.
///
/// See `docs/design/003-add-feature-command.md`. Nothing is written until
/// [plan] has succeeded for every part of the change.
class FeatureScaffold {
  /// Creates a scaffold rooted at [projectDir].
  FeatureScaffold({required this.projectDir});

  /// Root of the generated app being extended.
  final io.Directory projectDir;

  /// Locales the template ships. Every one gets the new keys.
  static const List<String> locales = ['en', 'ja', 'ko'];

  /// Computes the whole change without touching the disk.
  ///
  /// Throws [FeatureScaffoldException] for anything that makes the run
  /// impossible, so a refusal never leaves a half-written app behind.
  FeaturePlan plan({required String name, required bool tab}) {
    _checkName(name);
    _checkIsFluframeApp();
    _checkFeatureIsNew(name);

    final packageName = _readPackageName();
    final router = _readRouter(tab: tab);
    final title = humanizePackageName(name);

    final files = _files(name: name, packageName: packageName, title: title);
    final arbContents = <String, String>{};
    final untranslated = <String, List<String>>{};
    for (final locale in locales) {
      final path = 'lib/l10n/app_$locale.arb';
      final keys = {
        '${name}Title': title,
        if (tab) '${name}Tab': title,
      };
      arbContents[path] = _withKeys(path, keys, locale: locale);
      if (locale != 'en') untranslated[path] = keys.keys.toList();
    }

    return FeaturePlan(
      files: files,
      routerContents: _withRoutes(
        router,
        name: name,
        packageName: packageName,
        tab: tab,
      ),
      arbContents: arbContents,
      untranslated: untranslated,
    );
  }

  /// Writes [plan] to disk, cleaning up after itself if a write fails.
  void apply(FeaturePlan plan, {required String name}) {
    final featureDir = io.Directory(
      p.join(projectDir.path, 'lib', 'features', name),
    );
    final testDir = io.Directory(
      p.join(projectDir.path, 'test', 'features', name),
    );
    try {
      for (final file in plan.files) {
        final target = io.File(
          p.join(
            projectDir.path,
            p.joinAll(
              p.posix.split(file.path),
            ),
          ),
        );
        target.parent.createSync(recursive: true);
        target.writeAsStringSync(file.contents);
      }
      _write(routerPath, plan.routerContents);
      plan.arbContents.forEach(_write);
    } on Object {
      // A partially scaffolded feature is worse than none: it does not
      // compile, and the next run refuses because the directory exists.
      if (featureDir.existsSync()) featureDir.deleteSync(recursive: true);
      if (testDir.existsSync()) testDir.deleteSync(recursive: true);
      rethrow;
    }
  }

  void _write(String relative, String contents) {
    io.File(
      p.join(projectDir.path, p.joinAll(p.posix.split(relative))),
    ).writeAsStringSync(contents);
  }

  void _checkName(String name) {
    final rejection = packageNameRejection(name);
    if (rejection != null) {
      throw FeatureScaffoldException('Cannot use "$name": $rejection.');
    }
  }

  void _checkIsFluframeApp() {
    final hasMetadata = io.File(
      p.join(projectDir.path, '.fluframe.json'),
    ).existsSync();
    final hasPubspec = io.File(
      p.join(projectDir.path, 'pubspec.yaml'),
    ).existsSync();
    if (!hasMetadata && !hasPubspec) {
      throw FeatureScaffoldException(
        '${projectDir.path} is not a Flutter app (no pubspec.yaml).',
        hint: 'Run this from the root of an app made by fluframe create.',
      );
    }
  }

  void _checkFeatureIsNew(String name) {
    final dir = io.Directory(
      p.join(projectDir.path, 'lib', 'features', name),
    );
    if (dir.existsSync()) {
      throw FeatureScaffoldException(
        'lib/features/$name already exists.',
        hint: 'Delete it, or pick another name — nothing was changed.',
      );
    }
  }

  String _readPackageName() {
    final pubspec = io.File(p.join(projectDir.path, 'pubspec.yaml'));
    final match = RegExp(
      r'^name:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    final name = match?.group(1);
    if (name == null) {
      throw const FeatureScaffoldException(
        'pubspec.yaml has no "name:" line, so the package name to import '
        'from is unknown.',
      );
    }
    return name;
  }

  String _readRouter({required bool tab}) {
    final file = io.File(
      p.join(projectDir.path, p.joinAll(p.posix.split(routerPath))),
    );
    if (!file.existsSync()) {
      throw const FeatureScaffoldException(
        'This app has no $routerPath, so there is nowhere to register the '
        'route.',
      );
    }
    final contents = file.readAsStringSync();
    final required = [
      if (tab) ...[branchesAnchor, destinationsAnchor] else routesAnchor,
    ];
    for (final anchor in required) {
      if (!contents.contains(anchor)) {
        throw FeatureScaffoldException(
          '$routerPath has no "$anchor" line, so the CLI cannot tell where '
          'to register the route.',
          hint:
              'Apps generated before this anchor existed need it added: run '
              '`fluframe upgrade` first, or paste the line in by hand.',
        );
      }
    }
    return contents;
  }

  /// Inserts [lines] directly above the line carrying [anchor], matching
  /// the anchor's own indentation.
  String _insertAbove(String source, String anchor, List<String> lines) {
    final all = const LineSplitter().convert(source);
    final index = all.indexWhere((line) => line.contains(anchor));
    final indent = ' ' * (all[index].length - all[index].trimLeft().length);
    all.insertAll(index, [for (final line in lines) '$indent$line']);
    return '${all.join('\n')}\n';
  }

  String _withRoutes(
    String source, {
    required String name,
    required String packageName,
    required bool tab,
  }) {
    final screen = '${humanizePackageName(name).replaceAll(' ', '')}Screen';
    var result = _withImport(
      source,
      "import 'package:$packageName/features/$name/presentation/"
      "${name}_screen.dart';",
    );
    if (tab) {
      result = _insertAbove(result, branchesAnchor, [
        'StatefulShellBranch(',
        '  routes: [',
        '    GoRoute(',
        "      path: '/$name',",
        '      builder: (context, state) => const $screen(),',
        '    ),',
        '  ],',
        '),',
      ]);
      result = _insertAbove(result, destinationsAnchor, [
        'NavigationDestination(',
        '  icon: const Icon(Icons.widgets_outlined),',
        '  selectedIcon: const Icon(Icons.widgets),',
        '  label: l10n.${name}Tab,',
        '),',
      ]);
    } else {
      result = _insertAbove(result, routesAnchor, [
        'GoRoute(',
        "  path: '/$name',",
        '  builder: (context, state) => const $screen(),',
        '),',
      ]);
    }
    return result;
  }

  /// Inserts [directive] into the sorted `import` block.
  ///
  /// `directives_ordering` is fatal in the generated app, so the position
  /// matters. Sorting the block here rather than shelling out to
  /// `dart fix --apply` keeps the command from rewriting the user's own
  /// code as a side effect.
  String _withImport(String source, String directive) {
    if (source.contains(directive)) return source;
    final lines = const LineSplitter().convert(source);
    final imports = <int>[
      for (var i = 0; i < lines.length; i++)
        if (lines[i].startsWith('import ')) i,
    ];
    final at = imports.firstWhere(
      (i) => lines[i].compareTo(directive) > 0,
      orElse: () => imports.last + 1,
    );
    lines.insert(at, directive);
    return '${lines.join('\n')}\n';
  }

  String _withKeys(
    String relative,
    Map<String, String> keys, {
    required String locale,
  }) {
    final file = io.File(
      p.join(projectDir.path, p.joinAll(p.posix.split(relative))),
    );
    if (!file.existsSync()) {
      throw FeatureScaffoldException('This app has no $relative.');
    }
    final Map<String, Object?> decoded;
    try {
      decoded = Map<String, Object?>.from(
        jsonDecode(file.readAsStringSync()) as Map,
      );
    } on FormatException catch (error) {
      throw FeatureScaffoldException(
        '$relative is not valid JSON: '
        '${error.message}',
      );
    }
    for (final entry in keys.entries) {
      if (decoded.containsKey(entry.key)) {
        throw FeatureScaffoldException(
          '$relative already defines "${entry.key}".',
        );
      }
      decoded[entry.key] = entry.value;
      if (locale == 'en') {
        decoded['@${entry.key}'] = <String, Object?>{
          'description': 'Label for the $entry.key screen.',
        };
      }
    }
    return '${const JsonEncoder.withIndent('  ').convert(decoded)}\n';
  }

  List<PlannedFile> _files({
    required String name,
    required String packageName,
    required String title,
  }) {
    final klass = humanizePackageName(name).replaceAll(' ', '');
    return [
      PlannedFile(
        'lib/features/$name/data/${name}_repository.dart',
        _repositorySource(name: name, klass: klass),
      ),
      PlannedFile(
        'lib/features/$name/presentation/${name}_controller.dart',
        _controllerSource(name: name, klass: klass, packageName: packageName),
      ),
      PlannedFile(
        'lib/features/$name/presentation/${name}_screen.dart',
        _screenSource(name: name, klass: klass, packageName: packageName),
      ),
      PlannedFile(
        'test/features/$name/${name}_controller_test.dart',
        _controllerTestSource(
          name: name,
          klass: klass,
          packageName: packageName,
        ),
      ),
      PlannedFile(
        'test/features/$name/${name}_screen_test.dart',
        _screenTestSource(name: name, klass: klass, packageName: packageName),
      ),
    ];
  }

  String _repositorySource({required String name, required String klass}) =>
      '''
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data source for the $name feature.
///
/// Returns plain strings so the scaffold compiles and its tests pass with
/// no code generation. When this feature grows a real model, copy the
/// freezed + json_serializable pattern from `features/posts`.
class ${klass}Repository {
  /// Loads the items to show.
  Future<List<String>> fetchItems() async => const ['First', 'Second'];
}

/// Provider for the app-wide [${klass}Repository].
final ${name}RepositoryProvider = Provider<${klass}Repository>(
  (ref) => ${klass}Repository(),
);
''';

  String _controllerSource({
    required String name,
    required String klass,
    required String packageName,
  }) =>
      '''
import 'package:$packageName/features/$name/data/${name}_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Loads the $name items and exposes them as an [AsyncValue].
class ${klass}Controller extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() =>
      ref.watch(${name}RepositoryProvider).fetchItems();

  /// Discards the current state and re-runs [build].
  ///
  /// Failures are not rethrown: they already reach the UI as [AsyncError],
  /// and `RefreshIndicator.onRefresh` discards the returned future's error.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Surfaced via AsyncError state.
    }
  }
}

/// Provider for the [${klass}Controller].
final ${name}ControllerProvider =
    AsyncNotifierProvider<${klass}Controller, List<String>>(
      ${klass}Controller.new,
    );
''';

  String _screenSource({
    required String name,
    required String klass,
    required String packageName,
  }) =>
      '''
import 'package:$packageName/core/widgets/async_value_widget.dart';
import 'package:$packageName/features/$name/presentation/${name}_controller.dart';
import 'package:$packageName/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Screen for the $name feature.
class ${klass}Screen extends ConsumerWidget {
  /// Creates the $name screen.
  const ${klass}Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = ref.watch(${name}ControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.${name}Title)),
      body: AsyncValueWidget<List<String>>(
        value: items,
        onRetry: () => ref.invalidate(${name}ControllerProvider),
        data: (items) => ListView(
          children: [
            for (final item in items) ListTile(title: Text(item)),
          ],
        ),
      ),
    );
  }
}
''';

  String _controllerTestSource({
    required String name,
    required String klass,
    required String packageName,
  }) =>
      '''
import 'package:$packageName/features/$name/data/${name}_repository.dart';
import 'package:$packageName/features/$name/presentation/${name}_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

class _Fake${klass}Repository implements ${klass}Repository {
  @override
  Future<List<String>> fetchItems() async => const ['Only'];
}

void main() {
  group('${klass}Controller', () {
    test('build exposes the fetched items', () async {
      final container = createContainer(
        overrides: [
          ${name}RepositoryProvider.overrideWithValue(
            _Fake${klass}Repository(),
          ),
        ],
      );

      await expectLater(
        container.read(${name}ControllerProvider.future),
        completion(const ['Only']),
      );
    });
  });
}
''';

  String _screenTestSource({
    required String name,
    required String klass,
    required String packageName,
  }) =>
      '''
import 'package:$packageName/features/$name/data/${name}_repository.dart';
import 'package:$packageName/features/$name/presentation/${name}_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/helpers.dart';

class _Fake${klass}Repository implements ${klass}Repository {
  @override
  Future<List<String>> fetchItems() async => const ['Only'];
}

void main() {
  group('${klass}Screen', () {
    testWidgets('renders the fetched items', (tester) async {
      await tester.pumpApp(
        const ${klass}Screen(),
        overrides: [
          ${name}RepositoryProvider.overrideWithValue(
            _Fake${klass}Repository(),
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Only'), findsOneWidget);
    });
  });
}
''';
}
