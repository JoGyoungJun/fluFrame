import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Provides the `templates/` root of a published fluframe [version];
/// injectable so tests can serve local fixtures instead of the network.
typedef BundleProvider = Future<Directory> Function(String version);

/// A published bundle could not be fetched, or could not be trusted.
///
/// The requested [version] travels with the failure. This surfaces in the
/// CLI's top-level handler, many frames away from whoever asked for it,
/// and "404" on its own is not something a user can act on.
class BundleException implements Exception {
  /// Describes [message] going wrong while fetching fluframe [version],
  /// with an optional [hint] naming the way out.
  BundleException(this.version, this.message, {this.hint});

  /// The fluframe version whose bundle was requested.
  final String version;

  /// What went wrong, phrased for a terminal.
  final String message;

  /// What the user can do about it, when there is something.
  final String? hint;

  @override
  String toString() => message;
}

/// Downloads the pub.dev archive of fluframe [version] and extracts its
/// `templates/` directory (the app bundle + addons) into a temp folder.
///
/// Published bundles are a permanent part of the upgrade contract
/// (ADR 0002): every released version's template stays reconstructable.
///
/// Throws [BundleException] for everything a user can actually hit — an
/// unpublished version, an offline machine, a damaged archive — so the
/// CLI can report it as a sentence instead of a stack trace.
Future<Directory> downloadPublishedBundle(String version) async =>
    extractBundleTemplates(await _downloadArchive(version), version);

/// Fetches and decodes the published tarball of fluframe [version].
///
/// Split from the extraction so that a disk error while unpacking is not
/// reported as a network failure.
Future<Archive> _downloadArchive(String version) async {
  final client = HttpClient();
  try {
    final info = await _getJson(
      client,
      Uri.parse('https://pub.dev/api/packages/fluframe/versions/$version'),
      version,
    );
    final archiveUrl = info['archive_url'] as String?;
    if (archiveUrl == null) {
      throw BundleException(
        version,
        'pub.dev knows fluframe $version but published no archive for it.',
      );
    }
    final bytes = await _getBytes(client, Uri.parse(archiveUrl), version);
    try {
      return TarDecoder().decodeBytes(const GZipDecoder().decodeBytes(bytes));
    } on FormatException catch (error) {
      // ArchiveException is a FormatException, and an undecodable download
      // must not reach the CLI as one: the top-level handler reads a bare
      // FormatException as malformed .fluframe.json.
      throw BundleException(
        version,
        'The fluframe $version archive from pub.dev could not be read '
        '(${error.message}).',
        hint: 'The download may have been truncated — try again.',
      );
    }
  } on IOException catch (error) {
    // Offline, DNS, proxy, TLS: all IOException, none of them a fluframe
    // bug, and none worth a stack trace.
    throw BundleException(
      version,
      'Could not reach pub.dev to download the fluframe $version template '
      'bundle: $error',
      hint: 'Check your network connection and try again.',
    );
  } finally {
    client.close(force: true);
  }
}

/// Extracts the `templates/` tree of the fluframe [version] [archive] into
/// a fresh temp directory, and returns that `templates/` directory.
///
/// The result outlives this call: the upgrader reads the merge base out of
/// it for the rest of the run, so it cannot be deleted here — that would
/// be a use-after-delete. Only the failure paths clean up after
/// themselves; on a successful extraction the OS temp sweeper owns the
/// directory, one per upgrade run.
Directory extractBundleTemplates(Archive archive, String version) {
  final out = Directory.systemTemp.createTempSync('fluframe_bundle_');
  final root = p.normalize(out.absolute.path);
  try {
    var extracted = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      if (!entry.name.startsWith('templates/')) continue;
      // A tar member names its own path, and these bytes came off the
      // network: 'templates/../../../probe.txt' passes the prefix test and
      // then lands wherever it likes. Resolve the path first, and insist
      // it stayed inside the directory we made for it.
      final target = p.normalize(p.join(root, entry.name));
      if (!p.isWithin(root, target)) {
        throw BundleException(
          version,
          'The fluframe $version archive contains an entry that would be '
          'written outside the download directory: ${entry.name}',
          hint:
              'Nothing from it was kept. Please report this at '
              'https://github.com/JoGyoungJun/fluFrame/issues',
        );
      }
      File(target)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entry.content);
      extracted++;
    }
    if (extracted == 0) {
      throw BundleException(
        version,
        'fluframe $version ships no templates/ — versions before 0.1.0 '
        'cannot be upgrade bases.',
        hint: 'Pass --from with a version from 0.1.0 onwards.',
      );
    }
  } on Object {
    _deleteQuietly(out);
    rethrow;
  }
  return Directory(p.join(out.path, 'templates'));
}

/// Removes a half-written extraction directory.
///
/// Best effort on purpose: a cleanup failure here would replace the error
/// the caller is about to report with a far less useful one.
void _deleteQuietly(Directory directory) {
  try {
    directory.deleteSync(recursive: true);
  } on FileSystemException {
    // Nothing to do — the OS temp sweeper gets it eventually.
  }
}

Future<Map<String, dynamic>> _getJson(
  HttpClient client,
  Uri uri,
  String version,
) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode == HttpStatus.notFound) {
    throw BundleException(
      version,
      'pub.dev has no published fluframe $version, so there is no template '
      'bundle to upgrade from.',
      hint:
          'Check the version in .fluframe.json (or the one passed to '
          '--from) against https://pub.dev/packages/fluframe/versions',
    );
  }
  if (response.statusCode != 200) {
    throw BundleException(
      version,
      'pub.dev answered ${response.statusCode} when asked for fluframe '
      '$version ($uri).',
      hint: 'This is usually temporary — try again in a minute.',
    );
  }
  final body = await utf8.decodeStream(response);
  try {
    return jsonDecode(body) as Map<String, dynamic>;
  } on FormatException {
    throw BundleException(
      version,
      'pub.dev returned something other than JSON for fluframe $version.',
      hint: 'This is usually temporary — try again in a minute.',
    );
  }
}

Future<List<int>> _getBytes(HttpClient client, Uri uri, String version) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != 200) {
    throw BundleException(
      version,
      'Downloading the fluframe $version archive failed: $uri answered '
      '${response.statusCode}.',
      hint: 'This is usually temporary — try again in a minute.',
    );
  }
  final builder = BytesBuilder(copy: false);
  await response.forEach(builder.add);
  return builder.takeBytes();
}
