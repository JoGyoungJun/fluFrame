import 'dart:io' as io;

import 'package:args/command_runner.dart';
import 'package:fluframe/src/host_capabilities.dart' as host;
import 'package:fluframe/src/process_runner.dart';
import 'package:fluframe/src/sdk_constraint.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as p;

/// `fluframe doctor` — diagnoses the environment before a first create.
class DoctorCommand extends Command<int> {
  /// Creates the command; [runProcess] and [canCreateSymlink] are
  /// injectable for tests.
  DoctorCommand({
    RunProcess? runProcess,
    StringSink? out,
    bool Function()? canCreateSymlink,
    this.dartConstraint,
  }) : _runProcess = runProcess ?? defaultRunProcess,
       _out = out ?? io.stdout,
       _canCreateSymlink = canCreateSymlink ?? host.canCreateSymlink;

  final RunProcess _runProcess;
  final StringSink _out;
  final bool Function() _canCreateSymlink;

  /// Overrides the SDK constraint, for tests. In production this is `null`
  /// and the constraint is read from the resolved template's own
  /// `pubspec.yaml`, so there is exactly one copy of the floor.
  final String? dartConstraint;

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check that this machine can generate and run fluFrame apps.';

  /// The Dart SDK constraint declared by the resolved [template], or `null`
  /// when there is no template or its pubspec cannot be read.
  String? _constraintOf(io.Directory? template) {
    if (template == null) return null;
    final pubspec = io.File(p.join(template.path, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return null;
    try {
      return dartConstraintFrom(pubspec.readAsStringSync());
    } on io.FileSystemException {
      return null;
    }
  }

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

    final template = await resolveTemplateDirectory();

    // The template's own `environment: sdk:` is the floor, read from the
    // resolved bundle so there is never a second copy to drift. Without this
    // check a machine on an older stable channel is told "All set", then
    // `create` scaffolds for a minute and dies inside `flutter pub get` with
    // a raw pub solver error.
    final constraint = dartConstraint ?? _constraintOf(template);
    if (dart != null) {
      final found = parseSemVer(dart);
      switch (checkDartVersion(dart, constraint)) {
        case SdkVerdict.tooOld:
        case SdkVerdict.tooNew:
          fatal = true;
          _out
            ..writeln(
              '[!!] Dart ${found == null ? dart : formatSemVer(found)} does '
              'not satisfy the template, which needs $constraint.',
            )
            ..writeln(
              '     A generated app fails `flutter pub get` before it ever '
              'builds.',
            )
            ..writeln('     Upgrade the SDK: flutter upgrade');
        case SdkVerdict.unknown:
          _out.writeln(
            '[--] could not compare the Dart version with the template '
            'constraint; skipping that check.',
          );
        case SdkVerdict.ok:
          _out.writeln('[ok] Dart satisfies the template ($constraint)');
      }
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
