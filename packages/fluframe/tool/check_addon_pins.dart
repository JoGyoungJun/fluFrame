// Warns when an addon's pinned dependency major has fallen behind pub.dev.
//
// The constraints `fluframe add <addon>` writes into a user's pubspec are
// string literals in lib/src/backends.dart — `supabase_flutter:^2.17.1`
// and four siblings. They are in no pubspec, no lockfile and no dependabot
// entry, and a caret pin keeps resolving inside its own major forever, so
// nothing anywhere goes red when a new major lands: the e2e backend
// variants keep resolving 2.x, dependabot never files a PR, and the drift
// check only compares examples to the template. The pins quietly hold every
// newly generated app back while the bundled addon sources rot against an
// API nobody is watching (ADR-0001's 2026-08-06 amendment assigns this cost
// to "the scheduled dependency-watch passes" — this is that watch).
//
// Nightly, never on push: the verdict depends on pub.dev being up.
//   dart run tool/check_addon_pins.dart
//
// Exit 0 when every pin is on the latest major (minor/patch drift is
// reported, not failed — a caret pin absorbs it). Exit 1 when a major has
// moved: the injected sources are written against the pinned one, so that
// is a migration to schedule, not a number to bump. Exit 0 with a note when
// pub.dev could not be reached, so an outage is not a red nightly.
import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';

Future<void> main() async {
  final pins = <String, String>{};
  for (final addons in [backendAddons, errorReportingAddons, analyticsAddons]) {
    for (final addon in addons.values) {
      for (final dependency in addon.dependencies) {
        final parts = dependency.split(':');
        if (parts.length != 2) {
          stderr.writeln('Unparseable addon dependency: $dependency');
          exit(1);
        }
        pins['${addon.name}/${parts[0]}'] = parts[1];
      }
    }
  }

  if (pins.isEmpty) {
    stderr.writeln('No addon dependency pins found — has the shape changed?');
    exit(1);
  }

  final client = HttpClient();
  var behindMajor = 0;
  var unreachable = 0;
  try {
    for (final entry in pins.entries) {
      final package = entry.key.split('/').last;
      final pinned = entry.value;
      final latest = await _latestStable(client, package);
      if (latest == null) {
        unreachable++;
        stdout.writeln('?? $package — could not read pub.dev');
        continue;
      }
      final pinnedMajor = _major(pinned);
      final latestMajor = _major(latest);
      if (pinnedMajor == null || latestMajor == null) {
        stdout.writeln('?? $package — unparseable version ($pinned / $latest)');
        continue;
      }
      if (latestMajor > pinnedMajor) {
        behindMajor++;
        stdout.writeln(
          'MAJOR BEHIND  ${entry.key}: pinned $pinned, pub.dev has $latest',
        );
      } else if (latest != pinned.replaceFirst('^', '')) {
        stdout.writeln(
          'ok (in major)  ${entry.key}: pinned $pinned, pub.dev has $latest',
        );
      } else {
        stdout.writeln('ok            ${entry.key}: $pinned');
      }
    }
  } finally {
    client.close(force: true);
  }

  if (unreachable == pins.length) {
    stdout.writeln(
      '\npub.dev was unreachable for every package — not a '
      'verdict about the pins.',
    );
    return;
  }
  if (behindMajor > 0) {
    stderr.writeln(
      '\n$behindMajor addon pin(s) are a major behind. The injected sources '
      'are written against the pinned major, so this is a migration: update '
      'the addon source, then the constraint in lib/src/backends.dart, in '
      'one change.',
    );
    exit(1);
  }
  stdout.writeln('\nEvery addon pin is on the latest major.');
}

/// The newest non-prerelease version of [package], or null if unreachable.
Future<String?> _latestStable(HttpClient client, String package) async {
  try {
    final request = await client.getUrl(
      Uri.https('pub.dev', '/api/packages/$package'),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != 200) {
      await response.drain<void>();
      return null;
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, Object?>) return null;
    final latest = decoded['latest'];
    if (latest is! Map<String, Object?>) return null;
    final version = latest['version'];
    return version is String ? version : null;
  } on Object {
    // Any transport or shape failure is "unknown", never "up to date".
    return null;
  }
}

/// The major component of `^2.17.1` or `2.17.1`, or null if unparseable.
int? _major(String version) {
  final digits = RegExp(r'^\D*(\d+)').firstMatch(version);
  return digits == null ? null : int.tryParse(digits.group(1)!);
}
