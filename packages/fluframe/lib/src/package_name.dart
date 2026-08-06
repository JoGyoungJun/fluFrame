/// Validation helpers for Dart package names.
library;

const Set<String> _reservedWords = {
  'abstract',
  'as',
  'assert',
  'async',
  'await',
  'base',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'covariant',
  'default',
  'deferred',
  'do',
  'dynamic',
  'else',
  'enum',
  'export',
  'extends',
  'extension',
  'external',
  'factory',
  'false',
  'final',
  'finally',
  'for',
  'get',
  'hide',
  'if',
  'implements',
  'import',
  'in',
  'interface',
  'is',
  'late',
  'library',
  'mixin',
  'new',
  'null',
  'on',
  'operator',
  'part',
  'required',
  'rethrow',
  'return',
  'sealed',
  'set',
  'show',
  'static',
  'super',
  'switch',
  'sync',
  'this',
  'throw',
  'true',
  'try',
  'typedef',
  'var',
  'void',
  'when',
  'while',
  'with',
  'yield',
};

/// Windows reserved device names.
///
/// Windows resolves these as devices rather than paths in most APIs.
/// `nul` reliably fails outright (`Creation failed ... errno = 161`); the
/// rest survive directory creation on modern Windows but keep ambushing
/// the tools downstream — shell redirection, archivers, CI checkouts. The
/// failures surface as raw OS errno text a minute into `flutter create`,
/// so refuse the name up front instead.
const Set<String> windowsReservedNames = {
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
};

/// Names of packages the generated app depends on — its own template
/// dependencies plus everything the addons `pub add`.
///
/// pub rejects a package that lists itself as a dependency, so naming the
/// project `dio` produces `A package may not list itself as a dependency`
/// after generation has already written 230 files.
///
/// `package_name_test.dart` fails if this drifts from
/// `template/pubspec.yaml` or from the addon definitions.
const Set<String> generatedAppDependencyNames = {
  // template/pubspec.yaml
  'build_runner', 'cupertino_icons', 'dio', 'flutter', 'flutter_localizations',
  'flutter_riverpod', 'flutter_test', 'freezed', 'freezed_annotation',
  'go_router', 'intl', 'json_annotation', 'json_serializable', 'mocktail',
  'shared_preferences', 'very_good_analysis',
  // addon dependencies (lib/src/backends.dart)
  'amplitude_flutter', 'firebase_auth', 'firebase_core', 'sentry_flutter',
  'supabase_flutter',
  // not a dependency, but a project named `test` shadows the convention
  // every Dart tool assumes for the directory of the same name
  'test',
};

// Leading `_` is excluded as a policy choice, not because it breaks:
// pub and `flutter create` both accept `_private`. But it violates the
// pub.dev naming convention and lands an underscore in the iOS bundle
// identifier (`com.example._private`), which Apple discourages — and a
// generator should not hand people a name they will have to change.
final RegExp _packageNamePattern = RegExp(r'^[a-z][a-z0-9_]*$');

/// Whether [name] is usable as the package name of a generated app.
///
/// Stricter than pub's own rule, because a name that pub accepts can still
/// make generation fail: see [generatedAppDependencyNames] and
/// [windowsReservedNames].
bool isValidPackageName(String name) =>
    _packageNamePattern.hasMatch(name) &&
    !_reservedWords.contains(name) &&
    !windowsReservedNames.contains(name) &&
    !generatedAppDependencyNames.contains(name);

/// Explains, in one sentence, why [name] was rejected.
///
/// Returns `null` when [name] is fine. The generic "lower_snake_case, no
/// leading digit" message cannot tell someone why `dio` or `con` failed.
String? packageNameRejection(String name) {
  if (generatedAppDependencyNames.contains(name)) {
    return 'the generated app depends on a package called "$name", and '
        'pub rejects a package that lists itself as a dependency';
  }
  if (windowsReservedNames.contains(name)) {
    return '"$name" is a reserved device name on Windows, so a directory '
        'with that name cannot be created';
  }
  if (_reservedWords.contains(name)) {
    return '"$name" is a Dart reserved word';
  }
  if (!_packageNamePattern.hasMatch(name)) {
    return 'package names must be lower_snake_case and start with a letter '
        '(a-z), e.g. my_app';
  }
  return null;
}

final RegExp _orgSegmentPattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$');

/// Whether [org] is a valid organization identifier for `flutter create`:
/// dot-separated segments, each starting with a letter
/// (e.g. `com.example`, `dev.my_org.apps`).
bool isValidOrg(String org) =>
    org.isNotEmpty && org.split('.').every(_orgSegmentPattern.hasMatch);

/// Converts a package name into a human-readable title.
///
/// `my_cool_app` → `My Cool App`.
String humanizePackageName(String name) => name
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');
