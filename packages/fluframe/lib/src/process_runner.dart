import 'dart:convert';
import 'dart:io';

/// Signature of a process launcher, injectable for tests.
typedef RunProcess =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// Runs [executable] and decodes its output as UTF-8.
///
/// The encodings are not optional. Without them `Process.run` decodes
/// stdout/stderr with [systemEncoding] — cp949 on Korean Windows, cp932 on
/// Japanese — which destroys every non-ASCII byte the child process emits.
/// `fluframe upgrade` feeds that output straight back into the user's
/// source files, so a wrong codepage here silently corrupts their app.
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
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
}
