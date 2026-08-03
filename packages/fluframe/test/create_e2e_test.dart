@Tags(['e2e'])
library;

import 'dart:io';

import 'package:fluframe/src/project_generator.dart';
import 'package:fluframe/src/template_source.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// End-to-end: sync the publish bundle exactly like a release, generate a
/// real project FROM THE BUNDLE (the path published users hit), then make
/// sure it passes `flutter analyze` and `flutter test`.
///
/// Requires the Flutter SDK on PATH. Run with: dart test -t e2e
void main() {
  test(
    'bundle-generated project passes flutter analyze and flutter test',
    () async {
      // 1. Produce the bundle the way a release would.
      final sync = await Process.run(
        'dart',
        ['run', 'tool/sync_template.dart'],
        runInShell: true,
      );
      expect(
        sync.exitCode,
        0,
        reason: 'sync_template failed:\n${sync.stdout}\n${sync.stderr}',
      );

      final bundled = Directory(
        p.join(Directory.current.path, 'templates', 'app'),
      );
      expect(bundled.existsSync(), isTrue);
      // Regression guards for the publish pipeline: the bundle must contain
      // the test suite (an unanchored .pubignore `test/` once stripped it)
      // and the dot-less gitignore.
      expect(
        Directory(p.join(bundled.path, 'test')).listSync(recursive: true),
        isNotEmpty,
        reason: 'bundle must ship the template test suite',
      );
      expect(File(p.join(bundled.path, 'gitignore')).existsSync(), isTrue);

      // 2. The CLI's default resolution must prefer the bundle.
      final resolved = await resolveTemplateDirectory();
      expect(resolved, isNotNull);
      expect(p.canonicalize(resolved!.path), p.canonicalize(bundled.path));

      // 3. Generate from the bundle, exercising --description escaping.
      // Platforms stay at android+web: including `windows` makes
      // `flutter pub get` require symlink support (Windows Developer
      // Mode), which cannot be assumed on contributor machines.
      final temp = Directory.systemTemp.createTempSync('fluframe_e2e_');
      addTearDown(() {
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows can hold locks briefly; leaking a temp dir is harmless.
        }
      });

      final generator = ProjectGenerator(templateDirectory: resolved);
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        description: 'An e2e "quoted" description',
        platforms: const ['android', 'web'],
      );
      expect(code, 0);

      final projectPath = p.join(temp.path, 'demo_app');
      expect(
        Directory(p.join(projectPath, 'test')).listSync(recursive: true),
        isNotEmpty,
        reason: 'generated app must include the template test suite',
      );
      expect(
        File(p.join(projectPath, '.gitignore')).readAsStringSync(),
        contains('env/*.local.json'),
      );
      expect(
        File(p.join(projectPath, 'pubspec.yaml')).readAsStringSync(),
        contains(r'description: "An e2e \"quoted\" description"'),
      );

      // 4. The generated app must be green.
      final analyze = await Process.run(
        'flutter',
        ['analyze'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: 'flutter analyze failed:\n${analyze.stdout}\n${analyze.stderr}',
      );

      final testRun = await Process.run(
        'flutter',
        ['test'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(
        testRun.exitCode,
        0,
        reason: 'flutter test failed:\n${testRun.stdout}\n${testRun.stderr}',
      );
    },
  );

  test(
    'fully-stacked variant (supabase+sentry+amplitude) passes checks',
    () async {
      final sync = await Process.run(
        'dart',
        ['run', 'tool/sync_template.dart'],
        runInShell: true,
      );
      expect(sync.exitCode, 0, reason: '${sync.stdout}\n${sync.stderr}');

      final resolved = await resolveTemplateDirectory();
      expect(resolved, isNotNull);

      final temp = Directory.systemTemp.createTempSync('fluframe_e2e_sb_');
      addTearDown(() {
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows can hold locks briefly; leaking a temp dir is harmless.
        }
      });

      final generator = ProjectGenerator(templateDirectory: resolved!);
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        backend: 'supabase',
        errorReporting: 'sentry',
        analytics: 'amplitude',
        platforms: const ['android', 'web'],
      );
      expect(code, 0);

      final projectPath = p.join(temp.path, 'demo_app');
      expect(
        File(
          p.join(
            projectPath,
            'lib',
            'features',
            'auth',
            'data',
            'supabase_auth_repository.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(projectPath, 'lib', 'core', 'logging', 'error_handlers.dart'),
        ).readAsStringSync(),
        contains('Sentry.captureException'),
      );
      final mainContent = File(
        p.join(projectPath, 'lib', 'main.dart'),
      ).readAsStringSync();
      expect(mainContent, contains('Supabase.initialize'));
      expect(mainContent, isNot(contains('InMemoryAuthRepository(store)')));
      expect(
        File(p.join(projectPath, 'pubspec.yaml')).readAsStringSync(),
        contains('supabase_flutter'),
      );
      expect(
        File(p.join(projectPath, 'env', 'dev.json')).readAsStringSync(),
        contains('SUPABASE_URL'),
      );
      expect(
        File(p.join(projectPath, 'env', 'dev.json')).readAsStringSync(),
        contains('SENTRY_DSN'),
      );
      expect(
        File(p.join(projectPath, 'pubspec.yaml')).readAsStringSync(),
        contains('sentry_flutter'),
      );
      expect(
        File(p.join(projectPath, 'pubspec.yaml')).readAsStringSync(),
        contains('amplitude_flutter'),
      );
      expect(
        File(
          p.join(
            projectPath,
            'lib',
            'core',
            'analytics',
            'analytics_service.dart',
          ),
        ).readAsStringSync(),
        contains('AmplitudeAnalyticsService'),
      );

      final analyze = await Process.run(
        'flutter',
        ['analyze'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: 'flutter analyze failed:\n${analyze.stdout}\n${analyze.stderr}',
      );

      final testRun = await Process.run(
        'flutter',
        ['test'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(
        testRun.exitCode,
        0,
        reason: 'flutter test failed:\n${testRun.stdout}\n${testRun.stderr}',
      );
    },
  );

  test(
    'firebase backend variant passes flutter analyze and flutter test',
    () async {
      final sync = await Process.run(
        'dart',
        ['run', 'tool/sync_template.dart'],
        runInShell: true,
      );
      expect(sync.exitCode, 0, reason: '${sync.stdout}\n${sync.stderr}');

      final resolved = await resolveTemplateDirectory();
      expect(resolved, isNotNull);

      final temp = Directory.systemTemp.createTempSync('fluframe_e2e_fb_');
      addTearDown(() {
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows can hold locks briefly; leaking a temp dir is harmless.
        }
      });

      final generator = ProjectGenerator(templateDirectory: resolved!);
      final code = await generator.generate(
        name: 'demo_app',
        org: 'dev.example',
        outputDirectory: temp.path,
        backend: 'firebase',
        platforms: const ['android', 'web'],
      );
      expect(code, 0);

      final projectPath = p.join(temp.path, 'demo_app');
      expect(
        File(
          p.join(
            projectPath,
            'lib',
            'features',
            'auth',
            'data',
            'firebase_auth_repository.dart',
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(projectPath, 'lib', 'firebase_options.dart')).existsSync(),
        isTrue,
      );
      final mainContent = File(
        p.join(projectPath, 'lib', 'main.dart'),
      ).readAsStringSync();
      expect(mainContent, contains('Firebase.initializeApp'));
      expect(mainContent, isNot(contains('InMemoryAuthRepository(store)')));
      expect(
        File(p.join(projectPath, 'pubspec.yaml')).readAsStringSync(),
        contains('firebase_auth'),
      );

      final analyze = await Process.run(
        'flutter',
        ['analyze'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(
        analyze.exitCode,
        0,
        reason: 'flutter analyze failed:\n${analyze.stdout}\n${analyze.stderr}',
      );

      final testRun = await Process.run(
        'flutter',
        ['test'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(
        testRun.exitCode,
        0,
        reason: 'flutter test failed:\n${testRun.stdout}\n${testRun.stderr}',
      );
    },
  );
}
