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
    final heading = RegExp(r'^## (\S+)', multiLine: true).firstMatch(changelog);

    expect(heading, isNotNull, reason: 'CHANGELOG.md needs a ## heading');
    expect(
      heading!.group(1),
      pubspecVersion(),
      reason:
          'The newest CHANGELOG.md heading must name the version in '
          'pubspec.yaml (see the /release checklist).',
    );
  });
}
