import 'dart:convert';
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

    test('replaces malformed bytes rather than throwing', () async {
      // Regression (#184): a strict decoder raised a FormatException from
      // inside Process.run when a non-UTF-8 Windows console emitted its
      // own "is not recognized" text, and the top-level handler read that
      // as a malformed .fluframe.json — so a missing Flutter was reported
      // as a broken metadata file. The test above feeds valid UTF-8 and
      // passes either way; only malformed input separates
      // allowMalformed: true from false.
      final script = File(p.join(temp.path, 'malformed.dart'))
        ..writeAsStringSync('''
import 'dart:io';

void main() {
  stdout.add([0x80, 0x81]);
  stderr.add([0xfe, 0xff]);
}
''');

      final result = await defaultRunProcess(Platform.resolvedExecutable, [
        'run',
        script.path,
      ]);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(result.stdout.toString(), contains('\u{FFFD}'));
      expect(result.stderr.toString(), contains('\u{FFFD}'));
    });

    test('runs in the given working directory', () async {
      final script = File(p.join(temp.path, 'cwd.dart'))
        ..writeAsStringSync('''
import 'dart:io';

void main() => stdout.write(Directory.current.resolveSymbolicLinksSync());
''');
      final nested = Directory(p.join(temp.path, 'nested'))..createSync();

      final result = await defaultRunProcess(Platform.resolvedExecutable, [
        'run',
        script.path,
      ], workingDirectory: nested.path);

      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        p.canonicalize(result.stdout.toString().trim()),
        // Both sides fully resolved: macOS reports the temp dir as
        // /private/var while systemTemp says /var, and Windows hands back
        // the 8.3 short form (runner~1) for a long user name.
        // canonicalize alone normalizes without following either.
        p.canonicalize(nested.resolveSymbolicLinksSync()),
      );
    });

    // The shell boundary — which executables go through cmd.exe and which
    // arguments may reach it — had no test at all: reverting
    // `runInShell: _needsShell(executable)` to `runInShell: true` left the
    // whole suite green, and so did emptying the metacharacter set.
    group('shell boundary', () {
      /// A sentinel a planted `.bat` prints, chosen so nothing else can
      /// emit it by accident.
      const sentinel = 'fluframe-shim-was-used-4d1f';

      void plantBatch(String name) {
        File(p.join(temp.path, '$name.bat')).writeAsStringSync(
          '@echo off\r\necho $sentinel\r\n',
        );
      }

      test('every metacharacter cmd.exe reads as syntax is refused', () {
        // Runs on every platform on purpose: the rule is applied on every
        // platform (a path that scaffolds cleanly on Linux must not be a
        // silent overwrite on Windows), so it is pinned on every runner.
        for (final character in const ['&', '|', '<', '>', '^', '"', '%']) {
          final rejection = shellArgumentRejection(
            r'C:\dev' + character + r'tools\projects',
          );
          expect(
            rejection,
            isNotNull,
            reason: '"$character" must not reach cmd.exe unescaped',
          );
          expect(
            rejection,
            contains('"$character"'),
            reason: 'the message has to name the character it refused',
          );
        }
      });

      test('an ordinary path is not refused', () {
        expect(shellArgumentRejection(p.join(temp.path, 'my app')), isNull);
      });

      test(
        'POSIX shell-outs pass metacharacters through as argument text',
        () async {
          // The other half of the boundary, and until now the untested
          // one. `_needsShell` returns true for EVERY executable on POSIX,
          // and `shellArgumentRejection` refuses none of the characters a
          // POSIX shell reads as syntax (`;` `$` backtick `(` `)` newline)
          // — the refusal set is cmd.exe's. The whole POSIX safety margin
          // is one dart:io behaviour: it single-quotes each argument for
          // `sh -c`, so nothing can splice. That behaviour is real
          // (verified against dart 3.13.3 while writing this), but no test
          // observed it, so losing it would be silent — and `create`
          // passes a user-supplied `-o` straight into a shelled-out
          // `flutter create`.
          const hostile = r'pre$(id)mid;echo INJECTED;post`whoami`end';

          final result = await defaultRunProcess('echo', [hostile]);

          expect(result.exitCode, 0, reason: result.stderr.toString());
          expect(
            result.stdout.toString().trim(),
            hostile,
            reason:
                'dart:io stopped quoting arguments for sh -c; a path '
                'given to `create -o` can now splice a command',
          );
          // One line out means one command ran. A splice would append the
          // output of `echo INJECTED` (and of `id`/`whoami`) as extra
          // lines; asserting the text INJECTED is absent would be
          // meaningless here, since the literal appears in the argument
          // that is echoed back.
          expect(
            const LineSplitter().convert(result.stdout.toString()),
            hasLength(1),
          );
        },
        testOn: '!windows',
      );

      test(
        'git is never launched through the shell',
        () async {
          // `git` is deliberately absent from the batch-shim set. It is a
          // real .exe, and shelling it out makes PATHEXT apply — so a
          // git.bat sitting in the project directory would answer the
          // `git status --porcelain` that Upgrader._canUndo runs with that
          // very directory as its working directory, and could report a
          // dirty tree as clean (or the reverse) to the gate that decides
          // whether --apply can be undone.
          plantBatch('git');

          String output;
          try {
            final result = await defaultRunProcess('git', [
              '--version',
            ], workingDirectory: temp.path);
            output = '${result.stdout}${result.stderr}';
          } on ProcessException {
            // No git on PATH: CreateProcess found nothing, which is itself
            // proof the .bat next door was out of reach.
            output = '';
          }

          expect(
            output,
            isNot(contains(sentinel)),
            reason:
                'a git.bat in the working directory answered for git, '
                'so git is going through cmd.exe again',
          );
        },
        testOn: 'windows',
      );

      test(
        'flutter is launched through the shell, by design',
        () async {
          // The other half of the same decision, pinned so the shim set
          // cannot be emptied silently: CreateProcess cannot launch a batch
          // file, and on Windows `flutter` and `dart` exist only as .bat
          // shims, so those two have to go through cmd.exe. cmd resolves
          // the current directory before PATH, so the planted shim answers
          // even on a runner that has a real Flutter installed.
          plantBatch('flutter');

          final result = await defaultRunProcess('flutter', [
            '--version',
          ], workingDirectory: temp.path);

          expect(
            '${result.stdout}${result.stderr}',
            contains(sentinel),
            reason:
                'flutter stopped going through cmd.exe, so a real '
                'flutter.bat can no longer be launched at all',
          );
        },
        testOn: 'windows',
      );
    });
  });
}
