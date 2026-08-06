import 'dart:io';

import 'package:archive/archive.dart';
import 'package:fluframe/src/bundle_archive.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

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
}
