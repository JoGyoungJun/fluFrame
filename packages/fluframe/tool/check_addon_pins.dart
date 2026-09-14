// Warns when an addon's pinned dependency major has fallen behind pub.dev.
//
// The constraints `fluframe create --backend/--error-reporting/--analytics`
// writes into a user's pubspec are
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

import 'package:fluframe/src/addon_pins.dart';
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

  // A deadline on every request, for the reason bundle_archive.dart states
  // for its own: a registry that accepts the connection and then holds it
  // open would otherwise hang this job until GitHub's 6-hour default
  // timeout, reporting neither a pass nor a fail.
  final client = HttpClient()..connectionTimeout = _connectTimeout;
  final verdicts = <PinVerdict>[];
  try {
    for (final entry in pins.entries) {
      final package = entry.key.split('/').last;
      final pinned = entry.value;
      final latest = await _latestStable(client, package);
      final verdict = classifyPin(pinned: pinned, latest: latest);
      verdicts.add(verdict);

      switch (verdict) {
        case PinVerdict.unknown:
          stdout.writeln(
            latest == null
                ? '?? $package — could not read pub.dev'
                : '?? $package — unparseable version ($pinned / $latest)',
          );
        case PinVerdict.behindMajor:
          stdout.writeln(
            'MAJOR BEHIND  ${entry.key}: pinned $pinned, pub.dev has $latest',
          );
        case PinVerdict.behindInMajor:
          stdout.writeln(
            'ok (in major)  ${entry.key}: pinned $pinned, pub.dev has $latest',
          );
        case PinVerdict.aheadOfLatest:
          stdout.writeln(
            'ahead         ${entry.key}: pinned $pinned, pub.dev has $latest '
            '— retracted, or pinned before the release landed',
          );
        case PinVerdict.current:
          stdout.writeln('ok            ${entry.key}: $pinned');
      }
    }
  } finally {
    client.close(force: true);
  }

  if (verdicts.every((v) => v == PinVerdict.unknown)) {
    stdout.writeln(
      '\npub.dev was unreachable for every package — not a '
      'verdict about the pins.',
    );
    return;
  }
  if (shouldFail(verdicts)) {
    final behind = verdicts.where((v) => v == PinVerdict.behindMajor).length;
    stderr.writeln(
      '\n$behind addon pin(s) are a major behind. The injected sources '
      'are written against the pinned major, so this is a migration: update '
      'the addon source, then the constraint in lib/src/backends.dart, in '
      'one change.',
    );
    exit(1);
  }

  // Say what was actually checked. "Every addon pin is on the latest
  // major" reads as reassurance while every pin is a minor behind, which
  // is the state this watch reports today and does not fail on: a caret
  // constraint resolves those forward for users and for CI alike.
  final lagging = verdicts.where((v) => v == PinVerdict.behindInMajor).length;
  stdout.writeln(
    lagging == 0
        ? '\nEvery addon pin is on the latest major.'
        : '\nEvery addon pin is on the latest MAJOR. $lagging of '
              '${verdicts.length} lag a minor or patch, which a caret '
              'constraint resolves forward on its own — reported, not failed.',
  );
}

/// Matches the connect deadline `bundle_archive.dart` uses for pub.dev.
const Duration _connectTimeout = Duration(seconds: 10);

/// Ceiling for one package's metadata read, including the body.
const Duration _readTimeout = Duration(seconds: 30);

/// The newest non-prerelease version of [package], or null if unreachable.
Future<String?> _latestStable(HttpClient client, String package) async {
  try {
    return await _readLatest(client, package).timeout(_readTimeout);
  } on Object {
    // Any transport, timeout or shape failure is "unknown", never
    // "up to date".
    return null;
  }
}

Future<String?> _readLatest(HttpClient client, String package) async {
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
