import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

/// Provides the `templates/` root of a published fluframe [version];
/// injectable so tests can serve local fixtures instead of the network.
typedef BundleProvider = Future<Directory> Function(String version);

/// How long each stage of a bundle download may take before it is a
/// failure rather than a slow link.
typedef BundleTimeouts = ({
  Duration connect,
  Duration metadata,
  Duration download,
});

/// Where the published bundles are read from. The tests pass their own
/// loopback `HttpServer` through `downloadPublishedBundle`'s `registry`
/// parameter rather than replacing this.
final Uri pubDevRegistry = Uri.parse('https://pub.dev');

/// The shipped deadlines.
///
/// Every one of them exists to turn a hang into a sentence: without them a
/// blackholed connection leaves `fluframe upgrade` printing "Fetching…"
/// forever, and a user cannot tell that from a slow download.
///
/// * `connect` — a TCP+TLS handshake that has not completed in 10s is not
///   going to. This is the captive-portal case, where SYN goes nowhere.
/// * `metadata` — the version document is ~2 KB of JSON. 30s is far past
///   any working link and well short of "did it crash?".
/// * `download` — the 1.4.0 archive measured 104 KB, fetched in 0.4s. A
///   60s ceiling is a floor of roughly 14 kbit/s, slower than anything the
///   rest of the upgrade would survive anyway.
///
/// Deliberately not retries: a second attempt down the same blackhole
/// doubles the wait. Fail fast with a message that names the limit.
const BundleTimeouts defaultBundleTimeouts = (
  connect: Duration(seconds: 10),
  metadata: Duration(seconds: 30),
  download: Duration(seconds: 60),
);

/// The most content an archive may claim to hold before it is refused
/// unread.
///
/// gzip states its uncompressed length in the trailer (RFC 1952 §2.3.1),
/// so the size is knowable *without* decompressing — and decompressing
/// first is how a 104 KB download becomes a heap the CLI cannot survive.
/// The 1.4.0 archive measured 104 KB and its `templates/` tree is source
/// text, which does not inflate anywhere near tenfold, so 8 MB is roughly
/// two orders of magnitude of headroom and still bounded.
const int maxInflatedBundleBytes = 8 * 1024 * 1024;

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
///
/// The download is fetched over https and checked against the SHA-256
/// pub.dev publishes beside it before anything is inflated: what comes
/// out of the archive becomes the merge base `fluframe upgrade` writes
/// into the user's own source tree, so "it decompressed" is nowhere near
/// enough of a guarantee.
///
/// [registry] and [timeouts] exist for the tests, which serve the whole
/// exchange from a local `HttpServer` — the real network is never a test
/// dependency.
Future<Directory> downloadPublishedBundle(
  String version, {
  Uri? registry,
  BundleTimeouts timeouts = defaultBundleTimeouts,
}) async => extractBundleTemplates(
  await _downloadArchive(version, registry ?? pubDevRegistry, timeouts),
  version,
);

/// Fetches and decodes the published tarball of fluframe [version].
///
/// Split from the extraction so that a disk error while unpacking is not
/// reported as a network failure.
Future<Archive> _downloadArchive(
  String version,
  Uri registry,
  BundleTimeouts timeouts,
) async {
  final client = HttpClient()..connectionTimeout = timeouts.connect;
  try {
    final info = await _getJson(
      client,
      registry.resolve('/api/packages/fluframe/versions/$version'),
      version,
      timeouts.metadata,
    );
    final archiveUrl = info['archive_url'] as String?;
    if (archiveUrl == null) {
      throw BundleException(
        version,
        'pub.dev knows fluframe $version but published no archive for it.',
      );
    }
    // pub.dev publishes the archive's digest in the same document as its
    // URL. Without it nothing ties the download to what pub.dev holds —
    // see _verifyDigest — so a document that omits it is not something to
    // build a merge base out of.
    final expectedDigest = info['archive_sha256'] as String?;
    if (expectedDigest == null) {
      throw BundleException(
        version,
        'pub.dev published no checksum for the fluframe $version archive, '
        'so there is no way to prove the download is the one it published.',
        hint:
            'Nothing was downloaded. fluframe upgrade merges the bundle '
            'into your own source tree, so an unverifiable archive is '
            'refused rather than trusted. Please report this at '
            'https://github.com/JoGyoungJun/fluFrame/issues',
      );
    }
    final archiveUri = Uri.parse(archiveUrl);
    _requireTrustedOrigin(archiveUri, registry, version);
    final bytes = await _getBytes(
      client,
      archiveUri,
      registry,
      version,
      timeouts.download,
    );
    _verifyDigest(bytes, expectedDigest, version);
    try {
      return TarDecoder().decodeBytes(_inflateComplete(bytes, version));
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

/// Refuses [uri] unless a template bundle may be fetched from it.
///
/// https, or the plain-http [registry] the caller named itself — nothing
/// else. `fluframe upgrade` merges the downloaded `templates/` into the
/// user's own source tree, so an archive that arrives over plain http is
/// an archive anyone on the path can author. The exception exists because
/// [registry] is overridable: the tests serve the whole exchange from a
/// loopback `HttpServer`, and a self-hosted mirror is the same shape. It
/// deliberately does not extend to a *redirect* away from that registry —
/// leaving the origin the caller named is exactly how an insecure hop
/// gets in.
void _requireTrustedOrigin(Uri uri, Uri registry, String version) {
  if (uri.isScheme('https')) return;
  if (uri.isScheme(registry.scheme) &&
      uri.host == registry.host &&
      uri.port == registry.port) {
    return;
  }
  throw BundleException(
    version,
    'The fluframe $version archive would be fetched over an insecure '
    'connection ($uri).',
    hint:
        'Nothing was downloaded. pub.dev serves its archives over https, '
        'and this one is merged into your own source tree — so a hop off '
        'https is refused rather than followed.',
  );
}

/// Refuses [bytes] that are not the archive pub.dev published.
///
/// The gzip CRC32 checked in [_inflateComplete] proves the download is
/// consistent with itself; it proves nothing about who wrote it, because
/// anyone who rewrites the bytes recomputes it for free. The published
/// SHA-256 is the only thing tying this download to what pub.dev holds,
/// so it is checked before a byte is inflated — what comes out of the
/// archive becomes the merge base for the user's own source tree.
void _verifyDigest(List<int> bytes, String expected, String version) {
  final actual = sha256.convert(bytes).toString();
  if (actual == expected.toLowerCase()) return;
  throw BundleException(
    version,
    'The fluframe $version archive does not match the SHA-256 pub.dev '
    'published for it: expected $expected, got $actual.',
    hint:
        'Nothing was unpacked. A proxy or a mirror rewriting the download '
        'is the usual cause — try again on a direct connection, and '
        'report it at https://github.com/JoGyoungJun/fluFrame/issues if '
        'it persists.',
  );
}

/// Inflates [bytes], refusing a gzip stream that lost its tail.
///
/// `archive` 4.0.9's `GZipDecoder` does not raise on a truncated stream —
/// it returns whatever it managed to inflate. So half a download comes
/// back as a *partial* archive, and the upgrader's three-way merge then
/// reads the files that never arrived as files the user deleted. An empty
/// inflate is no better: it surfaces as "this version ships no templates/",
/// which blames the version for a transfer problem.
///
/// gzip's last eight bytes are the CRC32 and the uncompressed length of
/// the data (RFC 1952 §2.3.1). A stream that lost its tail fails both,
/// because the bytes read as a trailer are mid-stream deflate output.
/// Measured against cuts from one byte short to almost the whole stream.
///
/// That declared length is also read *before* anything is decompressed,
/// against [maxInflatedBundleBytes]. A truncated stream reads mid-deflate
/// output as its trailer, so the size it claims is arbitrary — inflating
/// first to find that out means holding whatever it claimed.
List<int> _inflateComplete(List<int> bytes, String version) {
  // A gzip member is a 10-byte header plus an 8-byte trailer at minimum.
  if (bytes.length < 18) {
    throw _incompleteArchive(
      version,
      'only ${bytes.length} bytes arrived, too few to be a gzip archive',
    );
  }
  // ISIZE is the uncompressed size modulo 2^32.
  final declaredSize = _readLe32(bytes, bytes.length - 4);
  if (declaredSize > maxInflatedBundleBytes) {
    throw _incompleteArchive(
      version,
      'its trailer declares $declaredSize bytes of content, past the '
      '${maxInflatedBundleBytes ~/ (1024 * 1024)} MB ceiling this will '
      'inflate',
    );
  }
  final inflated = const GZipDecoder().decodeBytes(bytes);
  if (inflated.length % 0x100000000 != declaredSize) {
    throw _incompleteArchive(
      version,
      'it unpacks to ${inflated.length} bytes where its own trailer '
      'declares $declaredSize',
    );
  }
  if (getCrc32(inflated) != _readLe32(bytes, bytes.length - 8)) {
    throw _incompleteArchive(
      version,
      'its contents do not match the checksum it carries',
    );
  }
  return inflated;
}

BundleException _incompleteArchive(String version, String detail) =>
    BundleException(
      version,
      'The fluframe $version archive from pub.dev arrived incomplete: '
      '$detail.',
      hint:
          'Nothing was unpacked. This is a transfer problem rather than a '
          'problem with the version — try again.',
    );

/// Reads four little-endian bytes at [at] as an unsigned 32-bit integer.
int _readLe32(List<int> bytes, int at) =>
    bytes[at] |
    (bytes[at + 1] << 8) |
    (bytes[at + 2] << 16) |
    (bytes[at + 3] << 24);

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

/// Fails [operation] with a [BundleException] if it outlives [limit].
///
/// The deadline covers the whole exchange — connect, headers and body —
/// because a server that accepts the connection and then stalls is
/// indistinguishable, from here, from one that never answered. Nothing is
/// cancelled: the caller closes its client with `force: true` in a
/// `finally`, which is what actually drops the socket.
Future<T> _withDeadline<T>(
  Future<T> operation,
  Duration limit,
  Uri uri,
  String version,
) => operation.timeout(
  limit,
  onTimeout: () => throw BundleException(
    version,
    'Timed out after ${_describe(limit)} waiting for $uri.',
    hint:
        'fluframe upgrade rebuilds the merge base from the published '
        'bundle, so it has no offline mode. A captive portal or an '
        'unconfigured proxy is the usual cause — check the connection '
        'and try again.',
  ),
);

/// Renders [limit] the way the message needs to read: `250ms`, `30s`, `2m`.
String _describe(Duration limit) {
  // Sub-second is not a shipped value but is what the tests use, and
  // "Timed out after 0s" would be a bug report waiting to happen.
  if (limit.inSeconds < 1) return '${limit.inMilliseconds}ms';
  if (limit.inMinutes >= 1 && limit.inSeconds % 60 == 0) {
    return '${limit.inMinutes}m';
  }
  return '${limit.inSeconds}s';
}

Future<Map<String, dynamic>> _getJson(
  HttpClient client,
  Uri uri,
  String version,
  Duration limit,
) => _withDeadline(_readJson(client, uri, version), limit, uri, version);

Future<Map<String, dynamic>> _readJson(
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
      // 400 means the version string itself was rejected — a permanent
      // problem "try again in a minute" would have a user retrying
      // forever (#189). The upgrader validates the shape before fetching,
      // but this endpoint is reachable with other inputs too.
      hint: response.statusCode == HttpStatus.badRequest
          ? '"$version" does not look like a version pub.dev accepts — '
                'check it against '
                'https://pub.dev/packages/fluframe/versions'
          : 'This is usually temporary — try again in a minute.',
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

Future<List<int>> _getBytes(
  HttpClient client,
  Uri uri,
  Uri registry,
  String version,
  Duration limit,
) => _withDeadline(
  _readBytes(client, uri, registry, version),
  limit,
  uri,
  version,
);

Future<List<int>> _readBytes(
  HttpClient client,
  Uri uri,
  Uri registry,
  String version,
) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  // HttpClient follows redirects on its own, and pub.dev's archive URLs
  // do redirect — so the URL the version document named is not
  // necessarily the one that answered. A hop off https hands the merge
  // base to whoever answered instead, which is why the chain is walked
  // before a byte of the body is read. RedirectInfo.location is the raw
  // Location header and may be relative, so each hop resolves against the
  // one before it, exactly as HttpClient resolved it.
  var hop = uri;
  for (final redirect in response.redirects) {
    hop = hop.resolveUri(redirect.location);
    _requireTrustedOrigin(hop, registry, version);
  }
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
