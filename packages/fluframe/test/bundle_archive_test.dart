import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Deadlines for the cases that are supposed to succeed or fail fast.
///
/// Long enough that a loaded CI runner cannot trip them — a flaky timeout
/// in a test suite teaches people to re-run rather than to read.
const BundleTimeouts _patient = (
  connect: Duration(seconds: 5),
  metadata: Duration(seconds: 20),
  download: Duration(seconds: 20),
);

/// Deadlines for the hang tests, which have to actually elapse. Only the
/// stage under test is short — a tight limit on the stage that is supposed
/// to succeed would fail with the wrong URL in the message on a slow
/// runner, which is a flake dressed up as a pass.
const BundleTimeouts _metadataHangs = (
  connect: Duration(seconds: 5),
  metadata: Duration(milliseconds: 250),
  download: Duration(seconds: 20),
);

const BundleTimeouts _downloadHangs = (
  connect: Duration(seconds: 5),
  metadata: Duration(seconds: 20),
  download: Duration(milliseconds: 250),
);

void main() {
  group('extractBundleTemplates', () {
    /// Names of the extraction directories currently sitting in the system
    /// temp folder, so a test can prove a failed extraction cleaned up
    /// without depending on what was there beforehand.
    Set<String> bundleDirs() => Directory.systemTemp
        .listSync()
        .whereType<Directory>()
        .map((directory) => p.basename(directory.path))
        .where((name) => name.startsWith('fluframe_bundle_'))
        .toSet();

    test('extracts the templates/ tree and nothing else', () {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'templates/app/pubspec.yaml',
            'name: fluframe_app\n',
          ),
        )
        ..add(ArchiveFile.string('templates/addons.json', '{}\n'))
        ..add(ArchiveFile.string('lib/src/version.dart', "const v = '1';\n"));

      final templates = extractBundleTemplates(archive, '1.1.0');
      addTearDown(() => templates.parent.deleteSync(recursive: true));

      expect(p.basename(templates.path), 'templates');
      expect(
        File(p.join(templates.path, 'app', 'pubspec.yaml')).readAsStringSync(),
        'name: fluframe_app\n',
      );
      expect(File(p.join(templates.path, 'addons.json')).existsSync(), isTrue);
      // The rest of the published package is not part of the bundle.
      expect(
        Directory(p.join(templates.parent.path, 'lib')).existsSync(),
        isFalse,
      );
    });

    test('refuses an entry that would be written outside the download '
        'directory', () {
      // 'templates/..' still passes a startsWith('templates/') check, so a
      // published (or man-in-the-middled) archive could drop a file
      // anywhere the CLI can write. This one aims at the temp folder.
      const escapee = 'templates/../../fluframe_zip_slip_probe.txt';
      final probe = File(
        p.join(Directory.systemTemp.path, 'fluframe_zip_slip_probe.txt'),
      );
      addTearDown(() {
        if (probe.existsSync()) probe.deleteSync();
      });
      final before = bundleDirs();
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'templates/app/pubspec.yaml',
            'name: fluframe_app\n',
          ),
        )
        ..add(ArchiveFile.string(escapee, 'pwned'));

      expect(
        () => extractBundleTemplates(archive, '1.1.0'),
        throwsA(
          isA<BundleException>()
              .having((error) => error.version, 'version', '1.1.0')
              .having((error) => error.message, 'message', contains(escapee)),
        ),
      );
      expect(probe.existsSync(), isFalse);
      // Nothing partially extracted is left lying around either.
      expect(bundleDirs().difference(before), isEmpty);
    });

    test('reports a bundle with no templates/ and cleans up', () {
      final before = bundleDirs();
      final archive = Archive()
        ..add(ArchiveFile.string('lib/src/version.dart', "const v = '1';\n"));

      expect(
        () => extractBundleTemplates(archive, '0.0.9'),
        throwsA(
          isA<BundleException>().having(
            (error) => error.message,
            'message',
            contains('0.0.9 ships no templates/'),
          ),
        ),
      );
      expect(bundleDirs().difference(before), isEmpty);
    });
  });

  // Everything below drives a real HttpClient against a loopback
  // HttpServer. Before #122 none of these paths had a test at all — the
  // suite only ever reached the extraction above, and the download half
  // was the CLI's largest block of untested shipped behaviour.
  group('downloadPublishedBundle over a local server', () {
    late HttpServer server;
    late Uri registry;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      registry = Uri.parse('http://127.0.0.1:${server.port}');
    });

    tearDown(() async => server.close(force: true));

    bool isMetadata(HttpRequest request) =>
        request.uri.path.startsWith('/api/packages/');

    /// Answers [request] and closes it.
    ///
    /// The close future is deliberately unawaited: `Stream.listen` takes a
    /// synchronous callback, and finishing the response is the server's
    /// business rather than something the test has to sequence.
    void reply(
      HttpRequest request, {
      int? status,
      String? text,
      String? location,
      List<int>? bytes,
    }) {
      final response = request.response;
      if (status != null) response.statusCode = status;
      if (location != null) {
        response.headers.set(HttpHeaders.locationHeader, location);
      }
      if (text != null) response.write(text);
      if (bytes != null) response.add(bytes);
      unawaited(response.close());
    }

    /// A pub.dev version document pointing back at this server.
    ///
    /// The digest travels with the body the server is about to serve, the
    /// same way pub.dev publishes it — every download is checked against
    /// it now, so a document without one only ever exercises the refusal.
    /// [digest] overrides that, for the tests that want a document and a
    /// body which disagree.
    String metadataFor(
      String path, {
      List<int> archive = const [],
      String? digest,
    }) => jsonEncode({
      'archive_url': registry.resolve(path).toString(),
      'archive_sha256': digest ?? sha256.convert(archive).toString(),
    });

    List<int> tarGz(Archive archive) =>
        const GZipEncoder().encodeBytes(TarEncoder().encodeBytes(archive));

    test('extracts the templates/ tree of a served archive', () async {
      final archive = Archive()
        ..add(
          ArchiveFile.string(
            'templates/app/pubspec.yaml',
            'name: fluframe_app\n',
          ),
        )
        ..add(ArchiveFile.string('templates/addons.json', '{}\n'));
      final bytes = tarGz(archive);
      // The document carries the digest of exactly these bytes, the shape
      // pub.dev publishes — so this is also the proof that a bundle
      // matching its published checksum still gets through.
      final metadata = metadataFor(
        '/archives/fluframe-1.2.0.tar.gz',
        archive: bytes,
      );
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadata);
        } else {
          reply(request, bytes: bytes);
        }
      });

      final templates = await downloadPublishedBundle(
        '1.2.0',
        registry: registry,
        timeouts: _patient,
      );
      addTearDown(() => templates.parent.deleteSync(recursive: true));

      expect(
        File(p.join(templates.path, 'app', 'pubspec.yaml')).readAsStringSync(),
        'name: fluframe_app\n',
      );
      expect(File(p.join(templates.path, 'addons.json')).existsSync(), isTrue);
    });

    test('a 404 on the version document names the version and where to '
        'check it', () async {
      server.listen((request) => reply(request, status: HttpStatus.notFound));

      await expectLater(
        downloadPublishedBundle(
          '9.9.9',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>()
              .having((e) => e.version, 'version', '9.9.9')
              .having((e) => e.message, 'message', contains('fluframe 9.9.9'))
              .having((e) => e.hint, 'hint', contains('.fluframe.json')),
        ),
      );
    });

    test('any other non-200 reports the status code', () async {
      server.listen(
        (request) => reply(request, status: HttpStatus.internalServerError),
      );

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>().having(
            (e) => e.message,
            'message',
            contains('answered 500'),
          ),
        ),
      );
    });

    test(
      'a body that is not JSON is reported as such, not as a crash',
      () async {
        // What a captive portal or a proxy error page actually looks like.
        server.listen(
          (request) => reply(request, text: '<html>503 from a proxy</html>'),
        );

        await expectLater(
          downloadPublishedBundle(
            '1.2.0',
            registry: registry,
            timeouts: _patient,
          ),
          throwsA(
            isA<BundleException>().having(
              (e) => e.message,
              'message',
              contains('something other than JSON'),
            ),
          ),
        );
      },
    );

    test('a version document with no archive_url is reported', () async {
      server.listen(
        (request) => reply(request, text: jsonEncode({'version': '1.2.0'})),
      );

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>().having(
            (e) => e.message,
            'message',
            contains('published no archive'),
          ),
        ),
      );
    });

    test('a non-200 on the archive itself names the archive URL', () async {
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadataFor('/archives/gone.tar.gz'));
        } else {
          reply(request, status: HttpStatus.forbidden);
        }
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>()
              .having((e) => e.message, 'message', contains('answered 403'))
              .having((e) => e.message, 'message', contains('gone.tar.gz')),
        ),
      );
    });

    test(
      'an undecodable archive is a bundle error, not a FormatException',
      () async {
        // ArchiveException extends FormatException, and the CLI's top-level
        // handler reads a bare FormatException as a malformed .fluframe.json
        // — so this one has to be caught and re-worded at the source.
        //
        // Long enough to clear the "too few bytes to be a gzip archive"
        // guard, so it reaches the decoder and fails there. Truncation is a
        // different error with a different message; see the group below.
        //
        // The last four bytes are zeroed because they are now read as the
        // declared uncompressed size before anything is inflated, and
        // 0x7f7f7f7f would trip the size ceiling instead — a different
        // failure than the one this test is about.
        final body = List.filled(64, 0x7f)..fillRange(60, 64, 0);
        server.listen((request) {
          if (isMetadata(request)) {
            reply(
              request,
              text: metadataFor('/archives/corrupt.tar.gz', archive: body),
            );
          } else {
            reply(request, bytes: body);
          }
        });

        await expectLater(
          downloadPublishedBundle(
            '1.2.0',
            registry: registry,
            timeouts: _patient,
          ),
          throwsA(
            isA<BundleException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('could not be read'),
                )
                .having((e) => e.hint, 'hint', contains('truncated')),
          ),
        );
      },
    );

    test(
      'a download cut off mid-body is reported as a network failure',
      () async {
        // The realistic truncation: the server promises 4 KB and the
        // connection dies after a few bytes. dart:io raises HttpException,
        // which is an IOException — this pins it to the network wording
        // instead of letting the type escape unhandled.
        server.listen((request) {
          if (isMetadata(request)) {
            reply(request, text: metadataFor('/archives/cut-off.tar.gz'));
          } else {
            final response = request.response
              ..contentLength = 4096
              ..add(List.filled(8, 0x1f));
            // Closing short of contentLength is an error on this side too;
            // the client noticing is the point of the test.
            unawaited(response.close().catchError((Object _) {}));
          }
        });

        await expectLater(
          downloadPublishedBundle(
            '1.2.0',
            registry: registry,
            timeouts: _patient,
          ),
          throwsA(
            isA<BundleException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('Could not reach'),
                )
                .having((e) => e.hint, 'hint', contains('network connection')),
          ),
        );
      },
    );

    test('a server that accepts and never answers hits the deadline', () async {
      // The failure #122 is about. Not a refused connection, which fails
      // immediately, but an accepted one that goes nowhere — a captive
      // portal or a proxy blackhole. Without a deadline this test would
      // hang the suite instead of failing it.
      server.listen((request) {
        // Deliberately untouched: no status, no body, no close.
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _metadataHangs,
        ),
        throwsA(
          isA<BundleException>()
              .having((e) => e.message, 'message', startsWith('Timed out'))
              .having((e) => e.message, 'names the limit', contains('250ms'))
              .having(
                (e) => e.message,
                'names the URL',
                contains('/api/packages/fluframe/versions/1.2.0'),
              )
              .having((e) => e.hint, 'hint', contains('no offline mode')),
        ),
      );
    });

    test('a gzip stream that lost its tail is refused, at every cut', () async {
      // #145. archive 4.0.9's GZipDecoder does not raise on a truncated
      // stream — it returns what it managed to inflate. Cut at 20 bytes it
      // yields an EMPTY archive, which used to surface as "this version
      // ships no templates/", blaming the version for a transfer problem.
      // Cut around 100 it yields a PARTIAL one, which is worse: the
      // upgrader's merge base is then missing files it will report as
      // deletions the user never made.
      final full = tarGz(
        Archive()
          ..add(ArchiveFile.string('templates/app/main.dart', 'x' * 40000))
          ..add(ArchiveFile.string('templates/addons.json', '{}\n')),
      );
      // The requested version selects the cut, so one server covers them
      // all: /archives/cut-<n>.tar.gz serves the first n bytes.
      //
      // Each document publishes the digest of the truncated bytes it is
      // about to serve, so the download passes the integrity check and
      // reaches this guard. That is the case worth pinning: a mirror
      // that published a digest of a half-archive would sail through the
      // checksum and still must not become a merge base.
      server.listen((request) {
        if (isMetadata(request)) {
          final keep = int.parse(request.uri.pathSegments.last);
          reply(
            request,
            text: metadataFor(
              '/archives/cut-$keep.tar.gz',
              archive: full.sublist(0, keep),
            ),
          );
        } else {
          final keep = int.parse(
            RegExp(r'cut-(\d+)').firstMatch(request.uri.path)!.group(1)!,
          );
          reply(request, bytes: full.sublist(0, keep));
        }
      });

      // 20 inflates to nothing; 100 and 105 to a partial archive;
      // full - 1 is one byte short, the case a length check alone misses.
      for (final keep in [20, 100, 105, full.length - 1]) {
        await expectLater(
          downloadPublishedBundle(
            '$keep',
            registry: registry,
            timeouts: _patient,
          ),
          throwsA(
            isA<BundleException>()
                .having(
                  (e) => e.message,
                  'message for cut $keep',
                  contains('arrived incomplete'),
                )
                .having(
                  (e) => e.hint,
                  'hint for cut $keep',
                  contains('transfer problem'),
                ),
          ),
          reason: 'a stream cut at $keep bytes must not unpack',
        );
      }
    });

    test('a body far too short to be an archive says so', () async {
      const stub = [0x1f, 0x8b, 0x08];
      server.listen((request) {
        if (isMetadata(request)) {
          reply(
            request,
            text: metadataFor('/archives/stub.tar.gz', archive: stub),
          );
        } else {
          reply(request, bytes: stub);
        }
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>().having(
            (e) => e.message,
            'message',
            contains('only 3 bytes arrived'),
          ),
        ),
      );
    });

    test('a complete archive still passes the trailer check', () async {
      // The guard has to let the real thing through: every published
      // bundle goes past it, so a false positive here would break every
      // upgrade rather than just a corrupted one.
      final archive = Archive()
        ..add(ArchiveFile.string('templates/app/main.dart', 'x' * 40000))
        ..add(ArchiveFile.string('templates/addons.json', '{}\n'));
      final bytes = tarGz(archive);
      server.listen((request) {
        if (isMetadata(request)) {
          reply(
            request,
            text: metadataFor('/archives/whole.tar.gz', archive: bytes),
          );
        } else {
          reply(request, bytes: bytes);
        }
      });

      final templates = await downloadPublishedBundle(
        '1.2.0',
        registry: registry,
        timeouts: _patient,
      );
      addTearDown(() => templates.parent.deleteSync(recursive: true));

      expect(
        File(p.join(templates.path, 'app', 'main.dart')).readAsStringSync(),
        'x' * 40000,
      );
    });

    test('the deadline also covers a stalled archive download', () async {
      // Headers and one byte, then silence. A connect timeout cannot see
      // this: the connection is established and the transfer has begun.
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadataFor('/archives/stalled.tar.gz'));
        } else {
          request.response.add([0x1f]);
        }
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _downloadHangs,
        ),
        throwsA(
          isA<BundleException>()
              .having((e) => e.message, 'message', startsWith('Timed out'))
              .having(
                (e) => e.message,
                'names the URL',
                contains('stalled.tar.gz'),
              ),
        ),
      );
    });

    // The bundle that comes out of here is merged into the user's own
    // source tree, so "it decompressed" is not a statement about who
    // wrote it. Everything below is about proving it is pub.dev's.
    test('a version document with no checksum is refused', () async {
      // Without the published digest nothing ties the download to
      // pub.dev: the CRC32 inside the archive only says the bytes agree
      // with themselves, and a rewriter recomputes it for free.
      final document = jsonEncode({
        'archive_url': registry.resolve('/archives/x.tar.gz').toString(),
      });
      server.listen((request) => reply(request, text: document));

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>().having(
            (e) => e.message,
            'message',
            contains('published no checksum'),
          ),
        ),
      );
    });

    test('an archive that does not match its published checksum is '
        'refused', () async {
      final bytes = tarGz(
        Archive()..add(ArchiveFile.string('templates/addons.json', '{}\n')),
      );
      final metadata = metadataFor(
        '/archives/swapped.tar.gz',
        // 64 hex zeroes: a digest no archive has, so a mismatch is the
        // only thing this can be failing on.
        digest: '0' * 64,
      );
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadata);
        } else {
          reply(request, bytes: bytes);
        }
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>()
              .having(
                (e) => e.message,
                'message',
                contains('does not match the SHA-256'),
              )
              .having((e) => e.hint, 'hint', contains('Nothing was unpacked')),
        ),
      );
    });

    test('a checksum published in upper case still matches', () async {
      // pub.dev publishes lower-case hex; a mirror need not. Comparing
      // the two forms literally would refuse a bundle that is byte-for-
      // byte correct — the worst possible false positive here, since it
      // breaks every upgrade rather than a tampered one.
      final bytes = tarGz(
        Archive()..add(ArchiveFile.string('templates/addons.json', '{}\n')),
      );
      final metadata = metadataFor(
        '/archives/upper.tar.gz',
        digest: sha256.convert(bytes).toString().toUpperCase(),
      );
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadata);
        } else {
          reply(request, bytes: bytes);
        }
      });

      final templates = await downloadPublishedBundle(
        '1.2.0',
        registry: registry,
        timeouts: _patient,
      );
      addTearDown(() => templates.parent.deleteSync(recursive: true));

      expect(File(p.join(templates.path, 'addons.json')).existsSync(), isTrue);
    });

    test('an archive URL that leaves the registry over plain http is '
        'refused', () async {
      // HttpClient does not care what scheme a URL carries, and whatever
      // comes back is merged into the user's source tree. archives.invalid
      // can never resolve (RFC 2606), so a regression fails on DNS rather
      // than reaching a real host.
      final document = jsonEncode({
        'archive_url': 'http://archives.invalid/fluframe-1.2.0.tar.gz',
        'archive_sha256': '0' * 64,
      });
      server.listen((request) => reply(request, text: document));

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>()
              .having(
                (e) => e.message,
                'message',
                contains('insecure connection'),
              )
              .having(
                (e) => e.message,
                'names the host',
                contains('archives.invalid'),
              ),
        ),
      );
    });

    test('a redirect off the registry into plain http is refused', () async {
      // pub.dev's archive URLs redirect to a storage host and HttpClient
      // follows redirects on its own, so the URL in the version document
      // is not necessarily the one that answers. A hop off the origin the
      // caller named is a hop into an archive someone else wrote.
      final bytes = tarGz(
        Archive()..add(ArchiveFile.string('templates/addons.json', '{}\n')),
      );
      final elsewhere = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async => elsewhere.close(force: true));
      elsewhere.listen((request) {
        final response = request.response..add(bytes);
        // A perfectly good archive, so nothing but the hop itself can be
        // what this test fails on. The client hangs up on the refusal
        // without draining it, and a close that fails afterwards is the
        // server's business rather than a test failure.
        unawaited(response.close().catchError((Object _) {}));
      });
      final metadata = metadataFor('/archives/moved.tar.gz', archive: bytes);
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadata);
        } else {
          reply(
            request,
            status: HttpStatus.movedTemporarily,
            location: 'http://127.0.0.1:${elsewhere.port}/moved.tar.gz',
          );
        }
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>()
              .having(
                (e) => e.message,
                'message',
                contains('insecure connection'),
              )
              .having(
                (e) => e.message,
                'names the hop',
                contains('127.0.0.1:${elsewhere.port}'),
              ),
        ),
      );
    });

    test('an archive that declares more content than the ceiling is '
        'refused before it is inflated', () async {
      // gzip states its uncompressed length in the trailer, so the size
      // is knowable without decompressing — and decompressing first is
      // how a small download becomes a heap the CLI cannot survive.
      // The body below inflates perfectly well, so a ceiling checked
      // after the decoder would report the trailer mismatch instead:
      // which message comes out is the proof of the order.
      final bytes = tarGz(
        Archive()..add(ArchiveFile.string('templates/addons.json', '{}\n')),
      );
      final bomb = List<int>.from(bytes);
      const declared = maxInflatedBundleBytes + 1;
      for (var i = 0; i < 4; i++) {
        bomb[bomb.length - 4 + i] = (declared >> (8 * i)) & 0xff;
      }
      final metadata = metadataFor('/archives/bomb.tar.gz', archive: bomb);
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadata);
        } else {
          reply(request, bytes: bomb);
        }
      });

      await expectLater(
        downloadPublishedBundle(
          '1.2.0',
          registry: registry,
          timeouts: _patient,
        ),
        throwsA(
          isA<BundleException>()
              .having((e) => e.message, 'message', contains('ceiling'))
              .having(
                (e) => e.message,
                'names the declared size',
                contains('$declared'),
              ),
        ),
      );
    });
  });
}
