/// Keeping the published bundle free of things that must never ship.
///
/// `.pubignore` deliberately lets `templates/` into the published archive,
/// and `packages/fluframe/.gitignore` hides that directory from
/// `git status` — so nothing shows a maintainer what is about to be
/// uploaded. The exposure is the documented manual fallback in
/// CONTRIBUTING.md: `tool/publish.bat` syncs from the maintainer's working
/// tree and publishes, and publishing is irreversible.
///
/// Two guards, deliberately independent, so a mistake in one is caught by
/// the other:
///
/// * [GitignoreMatcher] filters the sync itself. Its rules come from the
///   project's own `template/.gitignore`, which documents `env/*.local.json`
///   as the place real secrets go — read rather than re-listed, so the two
///   cannot drift apart.
/// * [findSecretLikeFiles] scans the finished bundle for shapes no
///   `.gitignore` here mentions at all (`.env`, private keys, signing
///   material). It is the backstop for the filter being wrong, and it runs
///   over the whole `templates/` tree including the addon bundle.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Paths that must never appear in the published bundle, in `.gitignore`
/// syntax so [GitignoreMatcher] evaluates them with the same rules.
///
/// Broader than `template/.gitignore` on purpose: that file describes what
/// this template's own tooling produces, while the bundle is copied out of
/// whatever a maintainer happens to have in their working tree. The `!`
/// lines matter — an `.env.example` is documentation and is supposed to
/// ship, and a guard that cries wolf on it gets switched off.
const String bundleSecretPatterns = '''
# The project's own documented secret location (template/.gitignore).
*.local.json

# Environment files, except the ones that exist to be read as documentation.
.env
.env.*
!.env.example
!.env.sample
!.env.template

# Private keys, certificates and mobile signing material.
*.pem
*.key
*.der
*.p12
*.pfx
*.jks
*.keystore
*.mobileprovision
id_rsa
id_dsa
id_ecdsa
id_ed25519

# Cloud and CI credentials.
secrets.json
service-account*.json
*credentials*.json
.netrc
.npmrc
''';

/// A `.gitignore` file's patterns, compiled once for repeated matching.
class GitignoreMatcher {
  /// Compiles the patterns in [content] — the text of a `.gitignore`.
  ///
  /// Supports comments, blank lines, `!` negation, a trailing `/` for
  /// directory-only rules, a leading `/` for root-anchored rules, `*`, `?`
  /// and `**`. Character classes (`[a-z]`) are treated as literal text
  /// rather than half-implemented; nothing in this repo uses them, and a
  /// pattern that matches too much would silently drop template files.
  factory GitignoreMatcher.parse(String content) {
    final rules = <_IgnoreRule>[];
    for (final line in const LineSplitter().convert(content)) {
      final rule = _IgnoreRule.parse(line);
      if (rule != null) rules.add(rule);
    }
    return GitignoreMatcher._(rules);
  }

  const GitignoreMatcher._(this._rules);

  final List<_IgnoreRule> _rules;

  /// Whether git would ignore [relativePath], a path relative to the
  /// directory holding the `.gitignore`. Accepts either separator.
  ///
  /// Tests [relativePath] alone. The "everything inside an ignored
  /// directory is ignored" rule is the caller's, which walks top-down and
  /// stops descending — the same way git evaluates it, and it keeps a deep
  /// tree from re-testing every ancestor once per file.
  bool ignores(String relativePath, {bool isDirectory = false}) {
    final path = relativePath.replaceAll(r'\', '/');
    if (path.isEmpty) return false;
    // Last matching rule wins, which is what makes `!` able to re-include.
    var ignored = false;
    for (final rule in _rules) {
      if (rule.directoryOnly && !isDirectory) continue;
      if (rule.matches(path)) ignored = !rule.negated;
    }
    return ignored;
  }
}

class _IgnoreRule {
  _IgnoreRule._(
    this._regExp, {
    required this.negated,
    required this.directoryOnly,
  });

  /// Parses one `.gitignore` line, or `null` when it carries no rule.
  static _IgnoreRule? parse(String line) {
    // Trailing whitespace is not part of a pattern unless escaped; leading
    // whitespace is. Only the unescaped form appears in this repo.
    var pattern = line.trimRight();
    if (pattern.isEmpty || pattern.startsWith('#')) return null;

    var negated = false;
    if (pattern.startsWith('!')) {
      negated = true;
      pattern = pattern.substring(1);
    }

    var directoryOnly = false;
    if (pattern.endsWith('/')) {
      directoryOnly = true;
      pattern = pattern.substring(0, pattern.length - 1);
    }
    if (pattern.isEmpty) return null;

    final rooted = pattern.startsWith('/');
    final body = rooted ? pattern.substring(1) : pattern;
    if (body.isEmpty) return null;

    // A separator anywhere but the (already stripped) end anchors the
    // pattern to the .gitignore's own directory; otherwise it may match at
    // any depth below it.
    final anchored = rooted || body.contains('/');
    final prefix = anchored ? '' : '(?:.*/)?';
    return _IgnoreRule._(
      RegExp('^$prefix${_bodyToRegExp(body)}\$'),
      negated: negated,
      directoryOnly: directoryOnly,
    );
  }

  final RegExp _regExp;

  /// Whether this rule re-includes rather than ignores.
  final bool negated;

  /// Whether this rule only applies to directories (a trailing `/`).
  final bool directoryOnly;

  bool matches(String path) => _regExp.hasMatch(path);

  static String _bodyToRegExp(String body) {
    final segments = body.split('/');
    final buffer = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final isLast = i == segments.length - 1;
      if (segment == '**') {
        // `a/**` matches everything below a; `**/b` matches b at any depth,
        // including directly at the root — hence zero-or-more, not one.
        buffer.write(isLast ? '.*' : '(?:[^/]+/)*');
        continue;
      }
      buffer.write(_segmentToRegExp(segment));
      if (!isLast) buffer.write('/');
    }
    return buffer.toString();
  }

  static String _segmentToRegExp(String segment) {
    final buffer = StringBuffer();
    for (final rune in segment.runes) {
      final char = String.fromCharCode(rune);
      switch (char) {
        case '*':
          buffer.write('[^/]*');
        case '?':
          buffer.write('[^/]');
        default:
          buffer.write(RegExp.escape(char));
      }
    }
    return buffer.toString();
  }
}

/// Every file under [root] whose name matches [bundleSecretPatterns],
/// as paths relative to [root] with `/` separators, sorted.
///
/// Empty is the only acceptable result for a bundle about to be published.
List<String> findSecretLikeFiles(Directory root, {GitignoreMatcher? matcher}) {
  if (!root.existsSync()) return const [];
  final rules = matcher ?? GitignoreMatcher.parse(bundleSecretPatterns);
  final found = <String>[];
  for (final entity in root.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final relative = p.relative(entity.path, from: root.path);
    if (rules.ignores(relative)) found.add(relative.replaceAll(r'\', '/'));
  }
  return found..sort();
}
