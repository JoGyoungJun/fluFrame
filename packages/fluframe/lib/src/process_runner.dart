import 'dart:convert';
import 'dart:io';

/// Signature of a process launcher, injectable for tests.
typedef RunProcess =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// Runs the given executable and decodes its output as UTF-8.
///
/// The encodings are not optional. Without them `Process.run` decodes
/// stdout/stderr with `systemEncoding` — cp949 on Korean Windows, cp932 on
/// Japanese — which destroys every non-ASCII byte the child process emits.
/// `fluframe upgrade` feeds that output straight back into the user's
/// source files, so a wrong codepage here silently corrupts their app.
///
/// Malformed bytes are tolerated rather than thrown on. On those same
/// consoles cmd.exe's own "command not found" message is NOT UTF-8, and a
/// strict decoder raised a FormatException from inside `Process.run` —
/// which the top-level handler reads as malformed .fluframe.json, so a
/// missing Flutter was reported as a broken metadata file (#184). A
/// U+FFFD in a shell error message costs nothing; the exception did.
const Utf8Codec _lenientUtf8 = Utf8Codec(allowMalformed: true);

/// See [_lenientUtf8].
Future<ProcessResult> defaultRunProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: true,
    stdoutEncoding: _lenientUtf8,
    stderrEncoding: _lenientUtf8,
  );
}
