/// Reading and checking the Dart SDK constraint the template declares.
///
/// The floor is deliberately never written down twice. `fluframe doctor`
/// reads it out of the template bundle's own `pubspec.yaml`, so bumping the
/// template moves the check with it and the two cannot drift apart.
library;

/// A parsed `major.minor.patch`, ignoring any pre-release or build suffix.
typedef SemVer = ({int major, int minor, int patch});

/// The first `major.minor.patch` in [text], or `null` when there is none.
///
/// Tolerant on purpose — it is fed whole tool banners:
/// `Dart SDK version: 3.12.1 (stable) on "windows_x64"` and
/// `Flutter 3.44.0 • channel stable • https://github.com/flutter/flutter`.
SemVer? parseSemVer(String text) {
  final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(text);
  if (match == null) return null;
  return (
    major: int.parse(match.group(1)!),
    minor: int.parse(match.group(2)!),
    patch: int.parse(match.group(3)!),
  );
}

/// The `environment: sdk:` constraint declared in [pubspec], or `null`.
///
/// Hand-parsed because the CLI has no YAML dependency and this is the only
/// field it needs. The value pattern requires a digit or a comparator, which
/// is what keeps `sdk: flutter` under `dependencies:` from matching.
String? dartConstraintFrom(String pubspec) {
  final match = RegExp(
    r'''^\s+sdk:\s*['"]?([\^>=<~\d][^'"\r\n]*)''',
    multiLine: true,
  ).firstMatch(pubspec);
  return match?.group(1)?.trim();
}

/// The outcome of checking an installed SDK against the template.
enum SdkVerdict {
  /// The installed version satisfies the constraint.
  ok,

  /// Older than the constraint's floor — `flutter pub get` will fail.
  tooOld,

  /// At or past the constraint's exclusive upper bound.
  tooNew,

  /// The version or the constraint could not be read; nothing is claimed.
  unknown,
}

/// The inclusive floor and exclusive ceiling [constraint] describes.
///
/// Supports the caret form the template uses (`^3.12.1`) and an explicit
/// `>=3.12.1 <4.0.0`. Anything else returns `null` rather than a guess —
/// a wrong floor here rejects a machine that would have worked.
({SemVer min, SemVer? max})? boundsOf(String constraint) {
  final caret = RegExp(r'^\^(\d+\.\d+\.\d+)').firstMatch(constraint);
  if (caret != null) {
    final min = parseSemVer(caret.group(1)!);
    if (min == null) return null;
    // Caret on a >=1.0.0 version allows everything below the next major.
    final max = min.major > 0
        ? (major: min.major + 1, minor: 0, patch: 0)
        : (major: 0, minor: min.minor + 1, patch: 0);
    return (min: min, max: max);
  }

  final range = RegExp(
    r'^>=\s*(\d+\.\d+\.\d+)(?:\s*<\s*(\d+\.\d+\.\d+))?',
  ).firstMatch(constraint);
  if (range != null) {
    final min = parseSemVer(range.group(1)!);
    if (min == null) return null;
    final upper = range.group(2);
    return (min: min, max: upper == null ? null : parseSemVer(upper));
  }

  return null;
}

/// Checks the version in [versionOutput] against [constraint].
SdkVerdict checkDartVersion(String versionOutput, String? constraint) {
  if (constraint == null) return SdkVerdict.unknown;
  final version = parseSemVer(versionOutput);
  final bounds = boundsOf(constraint);
  if (version == null || bounds == null) return SdkVerdict.unknown;

  if (_compare(version, bounds.min) < 0) return SdkVerdict.tooOld;
  final max = bounds.max;
  if (max != null && _compare(version, max) >= 0) return SdkVerdict.tooNew;
  return SdkVerdict.ok;
}

/// Renders [version] back as `major.minor.patch`.
String formatSemVer(SemVer version) =>
    '${version.major}.${version.minor}.${version.patch}';

int _compare(SemVer a, SemVer b) {
  if (a.major != b.major) return a.major - b.major;
  if (a.minor != b.minor) return a.minor - b.minor;
  return a.patch - b.patch;
}
