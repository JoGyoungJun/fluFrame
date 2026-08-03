import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

/// Provides the `templates/` root of a published fluframe [version];
/// injectable so tests can serve local fixtures instead of the network.
typedef BundleProvider = Future<Directory> Function(String version);

/// Downloads the pub.dev archive of fluframe [version] and extracts its
/// `templates/` directory (the app bundle + addons) into a temp folder.
///
/// Published bundles are a permanent part of the upgrade contract
/// (ADR 0002): every released version's template stays reconstructable.
Future<Directory> downloadPublishedBundle(String version) async {
  final client = HttpClient();
  try {
    final info = await _getJson(
      client,
      Uri.parse('https://pub.dev/api/packages/fluframe/versions/$version'),
    );
    final archiveUrl = info['archive_url'] as String?;
    if (archiveUrl == null) {
      throw StateError('pub.dev returned no archive for fluframe $version.');
    }
    final bytes = await _getBytes(client, Uri.parse(archiveUrl));
    final tarBytes = const GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    final out = Directory.systemTemp.createTempSync('fluframe_bundle_');
    var extracted = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final name = entry.name;
      if (!name.startsWith('templates/')) continue;
      File(p.join(out.path, name))
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entry.content);
      extracted++;
    }
    if (extracted == 0) {
      throw StateError(
        'fluframe $version ships no templates/ — versions before 0.1.0 '
        'cannot be upgrade bases.',
      );
    }
    return Directory(p.join(out.path, 'templates'));
  } finally {
    client.close(force: true);
  }
}

Future<Map<String, dynamic>> _getJson(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != 200) {
    throw HttpException('GET $uri -> ${response.statusCode}', uri: uri);
  }
  return jsonDecode(await utf8.decodeStream(response)) as Map<String, dynamic>;
}

Future<List<int>> _getBytes(HttpClient client, Uri uri) async {
  final request = await client.getUrl(uri);
  final response = await request.close();
  if (response.statusCode != 200) {
    throw HttpException('GET $uri -> ${response.statusCode}', uri: uri);
  }
  final builder = BytesBuilder(copy: false);
  await response.forEach(builder.add);
  return builder.takeBytes();
}
