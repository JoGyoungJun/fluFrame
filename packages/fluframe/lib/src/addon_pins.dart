/// Classification for the addon dependency-pin watch.
///
/// The comparison lives here rather than in `tool/check_addon_pins.dart` so
/// it can be unit-tested, the same split `tool/check_example_drift.dart`
/// already uses for the same reason: `dart test` never loads `tool/`, and
/// CI only formats and analyzes it. The tool keeps the HTTP and the exit
/// code; this file decides what a pin means.
///
/// This matters more than the usual "extract for testability" argument. The
/// nightly job that calls it is the only thing watching five constraints
/// that live in no pubspec, no lockfile and no dependabot entry — and it
/// spent its first three runs unable to fail at all, because its verdict
/// was piped into `tee` under a shell without `pipefail`. A gate nothing
/// tests, whose failure path has never executed, is a gate in name only.
library;

/// What comparing a pinned constraint against pub.dev's latest stable says.
enum PinVerdict {
  /// The pin is exactly the latest stable version.
  current,

  /// Newer releases exist, but inside the pinned major — a caret pin
  /// resolves them on its own, so this is reported, never failed.
  behindInMajor,

  /// A newer major exists. The injected addon sources are written against
  /// the pinned major, so this is a migration to schedule.
  behindMajor,

  /// The pin is ahead of pub.dev's latest. Reachable after a retraction,
  /// or when the pin was bumped before the release landed. Never a
  /// failure, but it is not "current" either, and it used to be reported
  /// as if it were in-major drift.
  aheadOfLatest,

  /// pub.dev could not be read, or either version was unparseable. Never
  /// a verdict about the pin.
  unknown,
}

/// The major component of `^2.17.1` or `2.17.1`, or null if unparseable.
int? majorOf(String version) {
  final digits = RegExp(r'^\D*(\d+)').firstMatch(version);
  return digits == null ? null : int.tryParse(digits.group(1)!);
}

/// Classifies [pinned] (a constraint such as `^2.17.1`) against [latest]
/// (pub.dev's latest stable, or null when it could not be read).
PinVerdict classifyPin({required String pinned, required String? latest}) {
  if (latest == null) return PinVerdict.unknown;

  final pinnedMajor = majorOf(pinned);
  final latestMajor = majorOf(latest);
  if (pinnedMajor == null || latestMajor == null) return PinVerdict.unknown;

  if (latestMajor > pinnedMajor) return PinVerdict.behindMajor;
  if (latestMajor < pinnedMajor) return PinVerdict.aheadOfLatest;

  // Same major. The pin carries a constraint operator; compare against the
  // bare version it allows.
  return latest == pinned.replaceFirst('^', '')
      ? PinVerdict.current
      : PinVerdict.behindInMajor;
}

/// Whether a run holding these verdicts should fail the nightly job.
///
/// An all-unreachable run is an outage, not a verdict — failing on it
/// would make the watch cry wolf every time pub.dev has a bad night.
bool shouldFail(Iterable<PinVerdict> verdicts) {
  final all = verdicts.toList();
  if (all.isEmpty) return false;
  if (all.every((v) => v == PinVerdict.unknown)) return false;
  return all.any((v) => v == PinVerdict.behindMajor);
}
