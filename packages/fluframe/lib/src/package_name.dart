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

final RegExp _packageNamePattern = RegExp(r'^[a-z_][a-z0-9_]*$');

/// Whether [name] is a valid Dart package name (`lower_snake_case`, no
/// leading digit, not a reserved word).
bool isValidPackageName(String name) =>
    _packageNamePattern.hasMatch(name) && !_reservedWords.contains(name);

/// Converts a package name into a human-readable title.
///
/// `my_cool_app` → `My Cool App`.
String humanizePackageName(String name) => name
    .split('_')
    .where((part) => part.isNotEmpty)
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');
