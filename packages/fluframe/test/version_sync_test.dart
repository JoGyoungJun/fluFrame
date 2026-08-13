import 'dart:io';

import 'package:fluframe/src/command_runner.dart';
import 'package:test/test.dart';

void main() {
  test('cliVersion matches the pubspec.yaml version', () {
    // The release checklist bumps both places; this test makes forgetting
    // one of them a red suite instead of a shipped mismatch.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version: (.+)$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml must declare a version');
    expect(
      cliVersion,
      match!.group(1)!.trim(),
      reason:
          'Keep cliVersion in lib/src/command_runner.dart in sync '
          'with version: in pubspec.yaml (see the /release checklist).',
    );
  });
}
