import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
      List<int>? bytes,
    }) {
      final response = request.response;
      if (status != null) response.statusCode = status;
      if (text != null) response.write(text);
      if (bytes != null) response.add(bytes);
      unawaited(response.close());
    }

    /// A pub.dev version document pointing back at this server.
    String metadataFor(String path) =>
        jsonEncode({'archive_url': registry.resolve(path).toString()});

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
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadataFor('/archives/fluframe-1.2.0.tar.gz'));
        } else {
          reply(request, bytes: tarGz(archive));
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
        server.listen((request) {
          if (isMetadata(request)) {
            reply(request, text: metadataFor('/archives/corrupt.tar.gz'));
          } else {
            reply(request, bytes: List.filled(64, 0x7f));
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
      server.listen((request) {
        if (isMetadata(request)) {
          final version = request.uri.pathSegments.last;
          reply(request, text: metadataFor('/archives/cut-$version.tar.gz'));
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
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadataFor('/archives/stub.tar.gz'));
        } else {
          reply(request, bytes: const [0x1f, 0x8b, 0x08]);
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
      server.listen((request) {
        if (isMetadata(request)) {
          reply(request, text: metadataFor('/archives/whole.tar.gz'));
        } else {
          reply(request, bytes: tarGz(archive));
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
  });
}
