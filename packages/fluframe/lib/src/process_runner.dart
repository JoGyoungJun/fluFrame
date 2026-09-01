import 'dart:convert';
import 'dart:io';

/// Signature of a process launcher, injectable for tests.
typedef RunProcess =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// Executables that exist on Windows only as `.bat` shims.
///
/// `CreateProcess` cannot launch a batch file, so these two have to go
/// through cmd.exe there. `git` is deliberately absent: it is a real
/// `.exe`, and putting it through the shell made `PATHEXT` apply, so a
/// `git.bat` sitting in a project directory would answer the
/// `git status --porcelain` that `fluframe upgrade` runs with that very
/// directory as its working directory. Without the shell only a real
/// `git.exe` can.
const Set<String> _windowsBatchShims = {'flutter', 'dart'};

/// Whether [executable] has to be launched through a shell on this host.
///
/// Windows: only the shims above. cmd.exe is the reason
/// [shellArgumentRejection] has to exist, so nothing goes through it
/// that does not have to.
///
/// POSIX: everything, exactly as before. dart:io single-quotes every
/// argument for `sh -c` there, so nothing can splice; and a command the
/// shell cannot find comes back as exit 127 rather than as a
/// ProcessException, which is what keeps a missing `dart` a `dart fix`
/// warning instead of an exception thrown over a finished project tree.
bool _needsShell(String executable) =>
    !Platform.isWindows || _windowsBatchShims.contains(executable);

/// Characters cmd.exe reads as syntax rather than as argument text.
///
/// `<`, `>`, `|` and `"` are already illegal in a Windows path, so
/// refusing them costs nothing there. `&`, `^` and `%` are legal in one,
/// and are the ones that actually bite.
const String _shellMetacharacters = '&|<>^"%';

/// Explains why [argument] must not be handed to a shelled-out command,
/// or `null` when it is safe.
///
/// Windows reaches `flutter` only through cmd.exe (see
/// [_windowsBatchShims]), and dart:io appends the argument list to
/// `cmd /c` with no escaping at all: its one quoting rule fires on a
/// tab, a space or a `"`, so `&` never triggers it. That made
/// `fluframe create my_app -o "C:\dev&tools\projects"` arrive at cmd as
/// two commands. The first was `flutter create C:\dev`, which writes a
/// scaffold over whatever that directory already held — pubspec.yaml,
/// lib/main.dart, README.md, .gitignore, analysis_options.yaml. The
/// leftover fragment then exited 9009, the same code a missing Flutter
/// returns, so the user was told to install Flutter while a directory
/// they had never named was being overwritten.
///
/// Refused rather than escaped. A `^` escape is honoured only outside
/// quotes, and dart:io adds quotes exactly when the argument also holds
/// a space, so for `C:\a&b\my projects` the caret would survive into the
/// path — the same batch re-parse that ate a caret in #181. `%` cannot
/// be escaped for `cmd /c` at all. No escape exists that cannot corrupt
/// a path.
///
/// Applied on every platform even though only Windows splices: a path
/// that scaffolds cleanly for one developer must not be a silent
/// overwrite for the one on Windows, and a single rule is one a test can
/// pin on every runner.
String? shellArgumentRejection(String argument) {
  final characters = _shellMetacharacters.split('');
  for (final character in characters) {
    if (!argument.contains(character)) continue;
    final listed = characters.join(' ');
    return 'contains "$character", which cmd.exe reads as command syntax '
        'rather than as part of the path — none of $listed may appear';
  }
  return null;
}

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

/// See [_lenientUtf8] and [_needsShell].
Future<ProcessResult> defaultRunProcess(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) {
  return Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: _needsShell(executable),
    stdoutEncoding: _lenientUtf8,
    stderrEncoding: _lenientUtf8,
  );
}
