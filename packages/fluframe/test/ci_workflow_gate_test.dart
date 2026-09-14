// Structural gates over this repository's own `.github/` configuration.
//
// Every invariant here is one a human currently maintains by hand, and at
// least one has already regressed silently: `deploy-demo`'s `needs:` list
// once omitted `generated-android`, and the omission was invisible because
// a missing entry looks exactly like a deliberate exception.
//
// These tests read the real files rather than a fixture, so each one
// asserts its file resolved before relying on it — the same guard
// `project_generator_test.dart` carries, for the same reason: an unresolved
// path turns a gate into a no-op that passes while scanning nothing.

import 'dart:io';

import 'package:test/test.dart';

const _ciPath = '../../.github/workflows/ci.yml';
const _dependabotPath = '../../.github/dependabot.yml';
const _workflowDir = '../../.github/workflows';

String _read(String path) {
  expect(
    File(path).existsSync(),
    isTrue,
    reason:
        'run from packages/fluframe: "$path" must resolve, because this '
        'gate reads the real repository configuration and has nothing to '
        'check without it',
  );
  return File(path).readAsStringSync().replaceAll('\r\n', '\n');
}

/// Top-level keys under `jobs:` — two-space indented.
Set<String> _jobNames(String ci) {
  final names = <String>{};
  var inJobs = false;
  for (final line in ci.split('\n')) {
    if (line == 'jobs:') {
      inJobs = true;
      continue;
    }
    if (!inJobs) continue;
    if (line.isNotEmpty && !line.startsWith(' ')) break;
    final match = RegExp(r'^  ([a-z][a-z0-9-]*):\s*$').firstMatch(line);
    if (match != null) names.add(match.group(1)!);
  }
  return names;
}

/// The `needs:` block sequence of [job].
Set<String> _needsOf(String ci, String job) {
  final lines = ci.split('\n');
  final start = lines.indexOf('  $job:');
  expect(start, greaterThanOrEqualTo(0), reason: 'job "$job" must exist');
  final needs = <String>{};
  var inNeeds = false;
  for (var i = start + 1; i < lines.length; i++) {
    final line = lines[i];
    if (RegExp('^  [a-z]').hasMatch(line)) break;
    if (line.trimRight() == '    needs:') {
      inNeeds = true;
      continue;
    }
    if (!inNeeds) continue;
    final match = RegExp(r'^      - ([a-z][a-z0-9-]*)\s*$').firstMatch(line);
    if (match == null) break;
    needs.add(match.group(1)!);
  }
  return needs;
}

/// Whether this step's verdict is decided by a piped command whose exit
/// code the shell will discard.
///
/// Only the LAST command of a `run:` block decides the step. A `| tee` on
/// an earlier line — publishing a number to the job summary before a
/// separate command gates on it — is fine, and so is one that ends in
/// `|| true`, which says "diagnostic, never fails" out loud. What is not
/// fine is a gate that IS the piped command, under a shell without
/// pipefail.
bool _pipeSwallowsVerdict(List<String> step) {
  if (step.any((l) => l.trim() == 'shell: bash')) return false;
  if (step.any((l) => l.contains('pipefail'))) return false;

  final body = step.where((l) => l.trim().isNotEmpty).toList();
  if (body.isEmpty) return false;
  final last = body.last.trim();

  if (!last.contains('| tee')) return false;
  if (last.endsWith('|| true')) return false;
  return true;
}

void main() {
  group('ci.yml', () {
    test('deploy-demo needs every other job', () {
      final ci = _read(_ciPath);
      final jobs = _jobNames(ci);

      expect(
        jobs,
        contains('deploy-demo'),
        reason: 'ci.yml must parse into job names',
      );
      expect(
        jobs.length,
        greaterThan(5),
        reason: 'ci.yml job parse looks wrong — found only ${jobs.length}',
      );

      final needs = _needsOf(ci, 'deploy-demo');
      final expected = jobs.difference({'deploy-demo'});
      final missing = expected.difference(needs).toList()..sort();
      final extra = needs.difference(expected).toList()..sort();

      expect(
        needs,
        equals(expected),
        reason:
            'deploy-demo publishes the live demo from main, so it must wait '
            'on every gate. Missing from needs: $missing. '
            'Listed but not a job: $extra. '
            'Add the new job to deploy-demo needs in ci.yml.',
      );
    });

    test('cli-sdk-floor compiles the floor the CLI declares', () {
      final ci = _read(_ciPath);
      final lines = ci.split('\n');
      final start = lines.indexOf('  cli-sdk-floor:');
      expect(start, greaterThanOrEqualTo(0));

      String? pinned;
      for (var i = start + 1; i < lines.length; i++) {
        if (RegExp('^  [a-z]').hasMatch(lines[i])) break;
        final match = RegExp(
          r"^\s+sdk: '([0-9]+\.[0-9]+\.[0-9]+)'\s*$",
        ).firstMatch(lines[i]);
        if (match != null) {
          pinned = match.group(1);
          break;
        }
      }
      expect(
        pinned,
        isNotNull,
        reason: 'cli-sdk-floor must pin an exact sdk version',
      );

      final pubspec = _read('pubspec.yaml');
      final declared = RegExp(
        r'^\s+sdk: \^([0-9]+\.[0-9]+\.[0-9]+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec)?.group(1);
      expect(
        declared,
        isNotNull,
        reason: 'packages/fluframe/pubspec.yaml must declare sdk: ^x.y.z',
      );

      expect(
        pinned,
        equals(declared),
        reason:
            'The cli-sdk-floor job exists to compile the version pub.dev '
            'lets people install on. pubspec.yaml declares ^$declared but '
            'ci.yml compiles $pinned, so the real floor is unverified. '
            'Update the sdk value in the cli-sdk-floor job.',
      );
    });
  });

  group('dependabot.yml', () {
    test('build_runner is capped below 2.15.2 while freezed is deferred', () {
      final dependabot = _read(_dependabotPath);

      // freezed 3.x needs analyzer <11.0.0; build_runner >=2.15.2 needs
      // analyzer >=13.3.0. They cannot resolve together, so dependabot must
      // move freezed to propose any build_runner >=2.15.2 — a transitive
      // co-bump that `ignore` on freezed and `exclude-patterns` on the
      // group both fail to govern. PR #14 and PR #19 each landed an
      // undisclosed freezed 4 that way. Capping build_runner is the rule
      // that actually holds.
      expect(
        dependabot,
        contains(
          '- dependency-name: build_runner\n'
          "        versions: ['>=2.15.2']",
        ),
        reason:
            'Removing the build_runner cap lets a template-group PR carry '
            'freezed 3.2.5 -> 4.0.1 again without disclosing it. Lift this '
            'rule only in the same change that lifts the freezed ones.',
      );

      for (final name in ['freezed', 'freezed_annotation']) {
        expect(
          dependabot,
          contains(
            "- dependency-name: $name\n        versions: ['>=4.0.0-0']",
          ),
          reason: '$name must stay pinned below 4.x while the deferral holds',
        );
      }
    });
  });

  group('workflows', () {
    test('no gate exit code is swallowed by a pipe', () {
      final dir = Directory(_workflowDir);
      expect(
        dir.existsSync(),
        isTrue,
        reason: 'run from packages/fluframe: "$_workflowDir" must resolve',
      );

      final workflows = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.yml'))
          .toList();
      expect(workflows, isNotEmpty, reason: 'there must be workflows to scan');

      final offenders = <String>[];
      for (final file in workflows) {
        final name = file.uri.pathSegments.last;
        final lines = file
            .readAsStringSync()
            .replaceAll('\r\n', '\n')
            .split('\n');

        // Walk steps: one opens on a `      - ` line and runs to the next.
        var stepStart = -1;
        for (var i = 0; i <= lines.length; i++) {
          final opensStep =
              i < lines.length && RegExp(r'^      - \S').hasMatch(lines[i]);
          if (opensStep || i == lines.length) {
            if (stepStart >= 0) {
              final step = lines.sublist(stepStart, i);
              if (_pipeSwallowsVerdict(step)) {
                final label = step
                    .firstWhere(
                      (l) => l.contains('- name:'),
                      orElse: () => step.first,
                    )
                    .trim();
                offenders.add('$name line ${stepStart + 1}: $label');
              }
            }
            stepStart = opensStep ? i : -1;
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'GitHub default shell is `bash -e` WITHOUT pipefail, so a '
            'pipeline reports the exit code of its LAST command. A gate '
            'piped into `tee` therefore always succeeds, whatever it '
            'decided. Declaring `shell: bash` selects '
            '`bash --noprofile --norc -eo pipefail`, which propagates the '
            'failure. Offending steps: $offenders',
      );
    });
  });
}
