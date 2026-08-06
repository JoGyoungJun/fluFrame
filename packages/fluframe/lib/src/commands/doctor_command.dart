import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/host_capabilities.dart' as host;
import 'package:fluframe/src/process_runner.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:io/io.dart';

/// `fluframe doctor` — diagnoses the environment before a first create.
class DoctorCommand extends Command<int> {
  /// Creates the command; [runProcess] and [canCreateSymlink] are
  /// injectable for tests.
  DoctorCommand({
    RunProcess? runProcess,
    StringSink? out,
    bool Function()? canCreateSymlink,
  }) : _runProcess = runProcess ?? defaultRunProcess,
       _out = out ?? io.stdout,
       _canCreateSymlink = canCreateSymlink ?? host.canCreateSymlink;

  final RunProcess _runProcess;
  final StringSink _out;
  final bool Function() _canCreateSymlink;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check that this machine can generate and run fluFrame apps.';

  /// Probes [tool] and returns the first line of its output, or `null`
  /// when the tool is missing or failing.
  Future<String?> _probe(String tool, List<String> arguments) async {
    try {
      final result = await _runProcess(tool, arguments);
      if (result.exitCode != 0) return null;
      final lines = result.stdout.toString().trim().split('\n');
      return lines.isEmpty ? '' : lines.first.trim();
    } on io.ProcessException {
      return null;
    }
  }

  @override
  Future<int> run() async {
    var fatal = false;

    final flutter = await _probe('flutter', ['--version']);
    if (flutter == null) {
      fatal = true;
      _out
        ..writeln('[!!] Flutter SDK not found on PATH.')
        ..writeln(
          '     Install: https://docs.flutter.dev/get-started/install',
        );
    } else {
      _out.writeln('[ok] $flutter');
    }

    final dart = await _probe('dart', ['--version']);
    if (dart == null) {
      fatal = true;
      _out.writeln(
        '[!!] Dart not found on PATH (it ships with Flutter — check '
        'your PATH ordering).',
      );
    } else {
      _out.writeln('[ok] $dart');
    }

    final git = await _probe('git', ['--version']);
    if (git == null) {
      _out.writeln(
        '[--] git not found (optional, but you will want it: '
        'https://git-scm.com/downloads).',
      );
    } else {
      _out.writeln('[ok] $git');
    }

    final template = await resolveTemplateDirectory();
    if (template == null) {
      fatal = true;
      _out.writeln(
        '[!!] fluFrame template bundle not found. Reinstall with: '
        'dart pub global activate fluframe',
      );
    } else {
      _out.writeln('[ok] template bundle: ${template.path}');
    }

    // The default --platforms include windows and linux, whose plugins are
    // wired up with symbolic links. Without them `flutter pub get` fails
    // and `create` dies a minute in — so do not promise "All set" first.
    if (_canCreateSymlink()) {
      _out.writeln('[ok] symbolic links available');
    } else {
      fatal = true;
      _out
        ..writeln('[!!] Symbolic links are unavailable on this machine.')
        ..writeln(
          '     Flutter needs them to build with plugins, so '
          'flutter pub get',
        )
        ..writeln('     fails for the windows and linux platforms.');
      if (io.Platform.isWindows) {
        _out.writeln(
          '     Enable Developer Mode: start ms-settings:developers',
        );
      }
      _out.writeln(
        '     Or scope the app: '
        'fluframe create my_app --platforms=android,ios,web',
      );
    }

    _out.writeln(
      fatal
          ? '\nFix the [!!] items above, then re-run: fluframe doctor'
          : '\nAll set. Try: fluframe create my_app',
    );
    return fatal ? ExitCode.unavailable.code : ExitCode.success.code;
  }
}
