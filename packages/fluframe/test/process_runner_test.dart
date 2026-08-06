import 'dart:io';

import 'package:fluframe/src/process_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('defaultRunProcess', () {
    late Directory temp;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('fluframe_proc_test_');
    });

    tearDown(() {
      try {
        temp.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows can hold locks briefly; leaking a temp dir is harmless.
      }
    });

    test('decodes child output as UTF-8, not the OS codepage', () async {
      // Regression: Process.run defaults to systemEncoding — cp949 on
      // Korean Windows, cp932 on Japanese — so every multi-byte character
      // a child process emitted came back mangled. `fluframe upgrade` fed
      // that straight back into the user's source files.
      final script = File(p.join(temp.path, 'emit.dart'))
        ..writeAsStringSync('''
import 'dart:convert';
import 'dart:io';

void main() {
  stdout.add(utf8.encode('한국어 日本語 émoji'));
  stderr.add(utf8.encode('오류 エラー'));
}
''');

      final result = await defaultRunProcess(Platform.resolvedExecutable, [
        'run',
        script.path,
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout, '한국어 日本語 émoji');
      expect(result.stderr, '오류 エラー');
      // The failure mode this guards against replaces every non-ASCII byte
      // with a substitution character rather than dropping it.
      expect(result.stdout.toString(), isNot(contains('�')));
    });

    test('runs in the given working directory', () async {
      final script = File(p.join(temp.path, 'cwd.dart'))
        ..writeAsStringSync('''
import 'dart:io';

void main() => stdout.write(Directory.current.path);
''');
      final nested = Directory(p.join(temp.path, 'nested'))..createSync();

      final result = await defaultRunProcess(Platform.resolvedExecutable, [
        'run',
        script.path,
      ], workingDirectory: nested.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        p.canonicalize(result.stdout.toString().trim()),
        // resolveSymbolicLinksSync, not canonicalize alone: macOS reports
        // the temp dir as /private/var while systemTemp says /var, and
        // canonicalize normalizes without following links.
        p.canonicalize(nested.resolveSymbolicLinksSync()),
      );
    });
  });
}
