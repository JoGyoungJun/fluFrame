import 'dart:io';

import 'package:fluframe/src/command_runner.dart';
import 'package:test/test.dart';

void main() {
  // The version a publish from this checkout would ship. `dart test`
  // runs from the package root, which is where both files live.
  String pubspecVersion() {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version: (.+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');
    return match!.group(1)!.trim();
  }

  test('cliVersion matches the pubspec.yaml version', () {
    // The release checklist bumps both places; this test makes forgetting
    // one of them a red suite instead of a shipped mismatch.
    expect(
      cliVersion,
      pubspecVersion(),
      reason:
          'Keep cliVersion in lib/src/command_runner.dart in sync '
          'with version: in pubspec.yaml (see the /release checklist).',
    );
  });

  test('the newest CHANGELOG entry is the version being published', () {
    // The third leg of the same triple, and the only one that cannot be
    // repaired after the fact: pub.dev serves the CHANGELOG that shipped
    // with a version, and a published version is never replaced. Cutting
    // 1.7.0 with the top heading still reading `## 1.6.0` bakes the wrong
    // notes into that page for good. publish.yml runs this suite before
    // the upload, so a stale heading stops the release instead.
    final changelog = File('CHANGELOG.md').readAsStringSync();
    // Headings are `## <version>` and carry nothing else today. Only the
    // first token is compared, so appending a date later stays a passing
    // heading rather than becoming a false failure.
    final headings = RegExp(
      r'^## (\S+)',
      multiLine: true,
    ).allMatches(changelog).map((match) => match.group(1)!).toList();

    expect(headings, isNotEmpty, reason: 'CHANGELOG.md needs a ## heading');
    // Between releases the top heading may be the literal `Unreleased`,
    // accumulating notes for the next version — but only while the
    // heading below it still names the published pubspec version. At
    // release time step 1 renames `Unreleased`; forget that and bump
    // pubspec anyway, and neither branch here matches, so the release
    // still stops. Forget the pubspec bump instead and the rename makes
    // the first branch fail (and cliVersion above fails with it).
    final version = pubspecVersion();
    final newestPublished = headings.first == 'Unreleased'
        ? (headings.length > 1 ? headings[1] : null)
        : headings.first;
    expect(
      newestPublished,
      version,
      reason:
          'The newest CHANGELOG.md heading must name the version in '
          'pubspec.yaml — or sit directly under an `## Unreleased` '
          'section that is renamed at release time (see the /release '
          'checklist).',
    );
  });
}
