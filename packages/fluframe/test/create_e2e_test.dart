@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:fluframe/src/backends.dart';
import 'package:fluframe/src/command_runner.dart';
import 'package:fluframe/src/host_capabilities.dart';
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
      final mainContent = _readNormalized(
        p.join(projectPath, 'lib', 'main.dart'),
      );
      // Every SDK initializer has to land AFTER this line. It is where
      // uncaught errors start being reported, and it runs before runApp —
      // so anything that throws above it escapes into the root zone with
      // no handler and no widget tree to show it in.
      final hooksAt = mainContent.indexOf(
        'platformDispatcher.onError = onPlatformError;',
      );
      expect(
        hooksAt,
        isNonNegative,
        reason: 'the template error hooks are the anchor for both addons',
      );
      // The SDK is given the app runner, which is what installs
      // RunZonedGuardedIntegration and chains its handlers onto the
      // template's. It replaces the hand-rolled Sentry.captureException
      // calls that used to be patched into error_handlers.dart, reported
      // every error as `handled: true`, and lost crash-free sessions.
      expect(mainContent, contains('SentryFlutter.init'));
      expect(
        mainContent,
        contains('appRunner: start'),
        reason:
            'without appRunner the SDK never guards the zone runApp '
            'runs in, and zone errors are lost',
      );
      expect(
        mainContent.indexOf('SentryFlutter.init'),
        greaterThan(hooksAt),
        reason:
            'initialising above the template handlers lets those two '
            'assignments overwrite the ones the SDK just installed',
      );
      expect(
        File(
          p.join(projectPath, 'lib', 'core', 'logging', 'error_handlers.dart'),
        ).readAsStringSync(),
        isNot(contains('Sentry.captureException')),
        reason: 'the SDK integrations capture; manual calls would duplicate',
      );
      expect(mainContent, contains('Supabase.initialize'));
      expect(
        mainContent.indexOf('Supabase.initialize'),
        greaterThan(hooksAt),
        reason:
            'initialize() throws on an empty URL; above the hooks that '
            'throw is a black screen with the error nowhere to be seen',
      );
      expect(mainContent, isNot(contains('InMemoryAuthRepository(store)')));
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

      final pubspec = _readNormalized(p.join(projectPath, 'pubspec.yaml'));
      for (final addon in [supabaseAddon, sentryAddon, amplitudeAddon]) {
        _expectPinnedDependencies(pubspec, addon);
      }
      _expectAddonTestsShipped(projectPath, 'supabase');
      _expectAddonTestsShipped(projectPath, 'amplitude');
      _expectEmptyEnvPlaceholders(projectPath, const [
        'SUPABASE_URL',
        'SUPABASE_PUBLISHABLE_KEY',
        'SENTRY_DSN',
        'AMPLITUDE_API_KEY',
      ]);

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
      final mainContent = _readNormalized(
        p.join(projectPath, 'lib', 'main.dart'),
      );
      final hooksAt = mainContent.indexOf(
        'platformDispatcher.onError = onPlatformError;',
      );
      expect(
        hooksAt,
        isNonNegative,
        reason: 'the template error hooks are the anchor for this addon',
      );
      expect(mainContent, contains('Firebase.initializeApp'));
      expect(
        mainContent.indexOf('Firebase.initializeApp'),
        greaterThan(hooksAt),
        reason: 'initializeApp must run after the error hooks exist',
      );
      // DefaultFirebaseOptions.currentPlatform throws until `flutterfire
      // configure` has run, i.e. on the first launch of every generated
      // app. Unguarded, that throw also precedes runApp, so it used to be
      // a black screen with the error reported nowhere.
      expect(
        mainContent,
        matches(
          RegExp(
            r'try \{\s*await Firebase\.initializeApp\([\s\S]*?\}\s*'
            r'on Object catch \(error, stackTrace\) \{\s*'
            r'onPlatformError\(error, stackTrace\);',
          ),
        ),
        reason:
            'initializeApp must sit in a try/catch that reports the '
            'failure through the app error seam',
      );
      expect(mainContent, isNot(contains('InMemoryAuthRepository(store)')));
      _expectPinnedDependencies(
        _readNormalized(p.join(projectPath, 'pubspec.yaml')),
        firebaseAddon,
      );
      _expectAddonTestsShipped(projectPath, 'firebase');

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
    'the shipped default platform set generates and analyzes',
    () async {
      // The three cases above all pin platforms to android+web, so until
      // now nothing ever generated what an argument-less
      // `fluframe create my_app` actually produces. That is the command in
      // the README, and the one that broke: `windows` and `linux` pull in
      // plugins that need symlinks, and `flutter pub get` fails without
      // them. Skipped rather than pinned, so the gate is real wherever it
      // can run instead of quietly testing something else everywhere.
      final sync = await Process.run(
        'dart',
        ['run', 'tool/sync_template.dart'],
        runInShell: true,
      );
      expect(sync.exitCode, 0, reason: '${sync.stdout}\n${sync.stderr}');

      final resolved = await resolveTemplateDirectory();
      expect(resolved, isNotNull);

      final temp = Directory.systemTemp.createTempSync('fluframe_e2e_def_');
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
        // No `platforms:` — that is the whole point of this case.
      );
      expect(code, 0);

      final projectPath = p.join(temp.path, 'demo_app');
      for (final platform in defaultPlatforms) {
        expect(
          Directory(p.join(projectPath, platform)).existsSync(),
          isTrue,
          reason: 'flutter create should have scaffolded $platform/',
        );
      }

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
    },
    skip: canCreateSymlink()
        ? null
        : 'the windows/linux platform plugins need symlink support '
              '(on Windows: Developer Mode)',
  );

  test(
    'add feature --tab produces an app that still analyzes and tests',
    () async {
      // The unit tests scaffold against a fixture router. This is the only
      // check that the generated code actually compiles inside a real app —
      // that the imports resolve, the anchors are where the CLI thinks, and
      // the ARB keys survive `flutter gen-l10n`.
      final sync = await Process.run(
        'dart',
        ['run', 'tool/sync_template.dart'],
        runInShell: true,
      );
      expect(sync.exitCode, 0, reason: '${sync.stdout}\n${sync.stderr}');

      final resolved = await resolveTemplateDirectory();
      expect(resolved, isNotNull);

      final temp = Directory.systemTemp.createTempSync('fluframe_e2e_add_');
      addTearDown(() {
        try {
          temp.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows can hold locks briefly; leaking a temp dir is harmless.
        }
      });

      final generator = ProjectGenerator(templateDirectory: resolved!);
      expect(
        await generator.generate(
          name: 'demo_app',
          org: 'dev.example',
          outputDirectory: temp.path,
          platforms: const ['android', 'web'],
        ),
        0,
      );
      final projectPath = p.join(temp.path, 'demo_app');

      final added = await FluframeCommandRunner().run([
        'add',
        'feature',
        'billing',
        '--tab',
        '--project-dir',
        projectPath,
      ]);
      expect(added, 0);

      // gen-l10n is the user's step (the command says so), so run it here
      // exactly as the printed instructions do.
      final l10n = await Process.run(
        'flutter',
        ['gen-l10n'],
        workingDirectory: projectPath,
        runInShell: true,
      );
      expect(l10n.exitCode, 0, reason: '${l10n.stdout}\n${l10n.stderr}');

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

/// Contract tests each addon ships into the generated app, by addon name.
///
/// The addon SDKs only resolve inside a generated project, so those tests
/// live in `template_addons/<name>/test/` and are run by the `flutter
/// test` in every case above. Nothing else notices when they stop being
/// copied, and a suite that quietly disappears is worse than none.
const Map<String, String> _addonTestFiles = {
  'supabase': 'test/features/auth/data/supabase_auth_repository_test.dart',
  'firebase': 'test/features/auth/data/firebase_auth_repository_test.dart',
  'amplitude': 'test/core/analytics/amplitude_analytics_service_test.dart',
};

/// Reads [path] with CRLF normalised away.
///
/// The addon patcher rewrites every file it touches with `\n` endings, so
/// assertions on multi-line shapes must not depend on how git checked the
/// template out on this machine.
String _readNormalized(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

/// Asserts [pubspec] pins every dependency [addon] declares to the
/// constraint the addon asked for.
///
/// `flutter pub add <name>` writes whatever is latest at generation time,
/// so a bare name in the pubspec means the next upstream major breaks
/// newly generated apps on its release day, with no fluframe change to
/// blame. The constraint is written in afterwards precisely because it
/// cannot survive the command line on Windows.
void _expectPinnedDependencies(String pubspec, BackendAddon addon) {
  for (final dependency in addon.dependencies) {
    final (name, constraint) = splitDependency(dependency);
    expect(
      constraint,
      isNotNull,
      reason: '${addon.name}: $name must declare a version constraint',
    );
    expect(
      pubspec,
      contains('  $name: $constraint\n'),
      reason:
          'pubspec.yaml must carry "$name: $constraint", not the bare name '
          'pub add resolved on its own',
    );
  }
}

/// Asserts the addon named [addonName] shipped its contract tests into the
/// project at [projectPath].
void _expectAddonTestsShipped(String projectPath, String addonName) {
  final relative = _addonTestFiles[addonName];
  expect(relative, isNotNull, reason: 'no contract tests for $addonName');
  final path = p.join(projectPath, p.joinAll(relative!.split('/')));
  expect(
    File(path).existsSync(),
    isTrue,
    reason:
        'the $addonName addon must copy its test/ directory into the '
        'generated app; flutter test below is what runs it',
  );
}

/// Asserts every [keys] entry is present and EMPTY in the generated
/// `env/dev.json` and `env/prod.json`.
///
/// Empty is the contract, not an oversight: these files are committed, and
/// a placeholder host or key would make a fresh app dial a stranger
/// instead of staying inert on its in-memory fallbacks. Decoding them also
/// proves the addon env patches spliced valid JSON — a bad splice
/// otherwise surfaces only at `--dart-define-from-file` time.
void _expectEmptyEnvPlaceholders(String projectPath, List<String> keys) {
  for (final file in ['dev.json', 'prod.json']) {
    final env =
        jsonDecode(_readNormalized(p.join(projectPath, 'env', file)))
            as Map<String, dynamic>;
    for (final key in keys) {
      expect(
        env,
        containsPair(key, ''),
        reason: 'env/$file must ship $key as an empty placeholder',
      );
    }
  }
}
