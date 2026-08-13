/// Backend addon definitions (see ADR 0001): a backend variant is the
/// base template plus extra dependencies, bundled addon files, and
/// anchored patches on template-owned files.
library;

/// An exact-string edit on a template-owned file.
///
/// [anchor] must exist verbatim in [file]; generation fails loudly when
/// it does not (template drift protection — see ADR 0001).
class AddonPatch {
  /// Creates a patch replacing [anchor] with [replacement] in [file].
  const AddonPatch({
    required this.file,
    required this.anchor,
    required this.replacement,
  });

  /// Reads a patch from its [toJson] form.
  factory AddonPatch.fromJson(Map<String, Object?> json) => AddonPatch(
    file: json['file']! as String,
    anchor: json['anchor']! as String,
    replacement: json['replacement']! as String,
  );

  /// Project-relative path of the file to patch.
  final String file;

  /// Exact string that must be present in the file.
  final String anchor;

  /// Text that replaces the first occurrence of [anchor].
  final String replacement;

  /// JSON form shipped inside a published bundle.
  Map<String, Object?> toJson() => {
    'file': file,
    'anchor': anchor,
    'replacement': replacement,
  };
}

/// A generation addon applied on top of the base template overlay
/// (auth backends, error reporting, ...). Addons are stackable: each is
/// applied in turn with the same primitives.
class BackendAddon {
  /// Creates an addon definition.
  const BackendAddon({
    required this.name,
    required this.dependencies,
    required this.patches,
    this.postCreateNotes = const [],
    this.requiresFiles = true,
  });

  /// Reads an addon from its [toJson] form.
  factory BackendAddon.fromJson(Map<String, Object?> json) => BackendAddon(
    name: json['name']! as String,
    dependencies: [
      for (final dependency in json['dependencies']! as List<dynamic>)
        dependency as String,
    ],
    patches: [
      for (final patch in json['patches']! as List<dynamic>)
        AddonPatch.fromJson(patch as Map<String, Object?>),
    ],
    postCreateNotes: [
      for (final note
          in (json['postCreateNotes'] as List<dynamic>?) ?? const [])
        note as String,
    ],
    requiresFiles: json['requiresFiles'] as bool? ?? true,
  );

  /// Addon identifier (CLI option value, addon directory name).
  final String name;

  /// Packages installed with `flutter pub add`.
  final List<String> dependencies;

  /// Anchored edits applied after the addon files are copied.
  final List<AddonPatch> patches;

  /// Setup steps printed after generation.
  final List<String> postCreateNotes;

  /// Whether the addon ships bundled files. Patch-only addons set this
  /// to `false`; file-bearing addons keep the loud missing-bundle error.
  final bool requiresFiles;

  /// JSON form shipped inside a published bundle.
  Map<String, Object?> toJson() => {
    'name': name,
    'dependencies': dependencies,
    'patches': [for (final patch in patches) patch.toJson()],
    'postCreateNotes': postCreateNotes,
    'requiresFiles': requiresFiles,
  };
}

/// Name of the addon-registry file inside a published template bundle.
///
/// `fluframe upgrade` rebuilds the BASE of its three-way merge from the
/// bundle of the version an app was generated with. Patch anchors are
/// exact strings from that era's template, so applying the CURRENT CLI's
/// anchors to an OLD bundle fails as soon as the template moves a line —
/// which used to block the upgrade outright. A bundle that carries its
/// own definitions can always be reconstructed.
const String addonRegistryFileName = 'addons.json';

/// The addon registry of this CLI, as written into a bundle.
Map<String, Object?> encodeAddonRegistry() => {
  'schema': 1,
  'backends': _encodeAddons(backendAddons),
  'errorReporting': _encodeAddons(errorReportingAddons),
  'analytics': _encodeAddons(analyticsAddons),
};

Map<String, Object?> _encodeAddons(Map<String, BackendAddon> addons) => {
  for (final entry in addons.entries) entry.key: entry.value.toJson(),
};

/// The three addon maps read back from an [encodeAddonRegistry] payload.
typedef AddonRegistry = ({
  Map<String, BackendAddon> backends,
  Map<String, BackendAddon> errorReporting,
  Map<String, BackendAddon> analytics,
});

/// Reads a registry written by [encodeAddonRegistry].
///
/// Throws [FormatException] on anything it does not recognise; callers
/// fall back to this CLI's compiled-in definitions.
AddonRegistry decodeAddonRegistry(Map<String, Object?> json) {
  final schema = json['schema'];
  if (schema != 1) {
    throw FormatException('Unsupported addon registry schema: $schema');
  }
  return (
    backends: _decodeAddons(json['backends']),
    errorReporting: _decodeAddons(json['errorReporting']),
    analytics: _decodeAddons(json['analytics']),
  );
}

Map<String, BackendAddon> _decodeAddons(Object? json) {
  if (json == null) return const {};
  if (json is! Map<String, Object?>) {
    throw const FormatException('Addon registry section is not an object');
  }
  return {
    for (final entry in json.entries)
      entry.key: BackendAddon.fromJson(entry.value! as Map<String, Object?>),
  };
}

/// The Supabase auth backend (stage 2 of the backend roadmap).
const BackendAddon supabaseAddon = BackendAddon(
  name: 'supabase',
  // Pinned to the major the injected sources are written against: the
  // bundled repository uses `publishableKey:`, which 1.x does not have.
  // `pub add` without a constraint resolves to whatever is latest at
  // generation time, so the next major would break new apps on its
  // release day, with no CLI change to blame.
  dependencies: ['supabase_flutter:^2.17.1'],
  patches: [
    // main.dart: swap the repository import to the Supabase one.
    AddonPatch(
      file: 'lib/main.dart',
      anchor:
          "import 'package:fluframe_app/features/auth/data/auth_repository.dart';",
      replacement:
          "import 'package:fluframe_app/features/auth/data/supabase_auth_repository.dart';",
    ),
    // main.dart: SDK import (sorted after shared_preferences).
    //
    // Prefixed: supabase_flutter exports a `User`, and so does the
    // template's own auth domain — which main.dart names in its boot
    // state. An unprefixed import makes both ambiguous and the generated
    // app fails to analyze.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: "import 'package:shared_preferences/shared_preferences.dart';",
      replacement:
          "import 'package:shared_preferences/shared_preferences.dart';\n"
          "import 'package:supabase_flutter/supabase_flutter.dart' "
          'as supabase;',
    ),
    // main.dart: initialize Supabase from --dart-define-from-file config.
    //
    // Anchored AFTER the error hooks, not on ensureInitialized(): an
    // initialize() that throws before they are installed escapes into the
    // root zone, and since it also precedes runApp there is no widget
    // tree to show it — the user gets a black screen. Guarded on a
    // configured URL for the same reason.
    AddonPatch(
      file: 'lib/main.dart',
      anchor:
          '  WidgetsBinding.instance.platformDispatcher.onError = '
          'onPlatformError;',
      replacement:
          '  WidgetsBinding.instance.platformDispatcher.onError = '
          'onPlatformError;\n'
          '\n'
          '  if (SupabaseAuthRepository.isConfigured) {\n'
          '    await supabase.Supabase.initialize(\n'
          "      url: const String.fromEnvironment('SUPABASE_URL'),\n"
          '      publishableKey: const String.fromEnvironment(\n'
          "        'SUPABASE_PUBLISHABLE_KEY',\n"
          '      ),\n'
          '    );\n'
          '  }',
    ),
    // main.dart: restore the session from Supabase instead of the fake.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: 'await InMemoryAuthRepository(store).restoreSession()',
      replacement: 'await supabaseAuthOrFallback(store).restoreSession()',
    ),
    // auth_repository.dart: import the addon repository (legal circular
    // import, accepted in ADR 0001).
    AddonPatch(
      file: 'lib/features/auth/data/auth_repository.dart',
      anchor:
          "import 'package:fluframe_app/core/storage/key_value_store.dart';",
      replacement:
          "import 'package:fluframe_app/core/storage/key_value_store.dart';\n"
          "import 'package:fluframe_app/features/auth/data/supabase_auth_repository.dart';",
    ),
    // auth_repository.dart: swap the provider — the single backend seam.
    AddonPatch(
      file: 'lib/features/auth/data/auth_repository.dart',
      anchor:
          '(ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),',
      replacement:
          '(ref) => supabaseAuthOrFallback(ref.watch(keyValueStoreProvider)),',
    ),
    // env: configuration keys, left EMPTY on purpose. These files are
    // committed (see the template .gitignore), and an empty URL is what
    // keeps a fresh app on the in-memory fake instead of dialling a
    // placeholder host.
    AddonPatch(
      file: 'env/dev.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "SUPABASE_URL": "",\n'
          '  "SUPABASE_PUBLISHABLE_KEY": ""',
    ),
    AddonPatch(
      file: 'env/prod.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "SUPABASE_URL": "",\n'
          '  "SUPABASE_PUBLISHABLE_KEY": ""',
    ),
  ],
  postCreateNotes: [_supabaseSetupNote],
);

const String _supabaseSetupNote =
    'Supabase: copy env/dev.json to env/dev.local.json (gitignored) and put '
    'your real SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY there, then run with '
    '--dart-define-from-file=env/dev.local.json and enable Email/Password '
    'auth in your Supabase project. Until then the app runs on the '
    'in-memory auth fake.';

/// The Firebase auth backend (stage 3 of the backend roadmap).
const BackendAddon firebaseAddon = BackendAddon(
  name: 'firebase',
  // Pinned: see the note on supabaseAddon's dependencies.
  dependencies: ['firebase_core:^4.13.0', 'firebase_auth:^6.5.7'],
  patches: [
    // main.dart: swap the repository import to the Firebase one.
    AddonPatch(
      file: 'lib/main.dart',
      anchor:
          "import 'package:fluframe_app/features/auth/data/auth_repository.dart';",
      replacement:
          "import 'package:fluframe_app/features/auth/data/firebase_auth_repository.dart';",
    ),
    // main.dart: firebase_core sorts before every fluframe_app import.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: "import 'package:fluframe_app/app/app.dart';",
      replacement:
          "import 'package:firebase_core/firebase_core.dart';\n"
          "import 'package:fluframe_app/app/app.dart';",
    ),
    // main.dart: generated firebase_options import, emitted after the
    // LAST fluframe_app import — `features/…` sorts before
    // `firebase_options.dart`, and theme_preset_controller is the last
    // one. (The previous anchor named theme_mode_controller, which stopped
    // being last when theme_preset_controller was added; the misplacement
    // only survived because `dart fix --apply` re-sorts afterwards, and
    // that does not run under --no-pub or on the upgrade path.)
    AddonPatch(
      file: 'lib/main.dart',
      anchor:
          "import 'package:fluframe_app/features/settings/presentation/theme_preset_controller.dart';",
      replacement:
          "import 'package:fluframe_app/features/settings/presentation/theme_preset_controller.dart';\n"
          "import 'package:fluframe_app/firebase_options.dart';",
    ),
    // main.dart: initialize Firebase, after the error hooks are in place.
    //
    // DefaultFirebaseOptions.currentPlatform throws until `flutterfire
    // configure` has run. Anchored on ensureInitialized() that throw
    // escaped before the hooks existed AND before runApp, so there was no
    // widget tree — the first run of every --backend firebase app was a
    // black screen with no error anywhere. Now it is reported through the
    // app's own seam and the app boots on the in-memory fake.
    AddonPatch(
      file: 'lib/main.dart',
      anchor:
          '  WidgetsBinding.instance.platformDispatcher.onError = '
          'onPlatformError;',
      replacement:
          '  WidgetsBinding.instance.platformDispatcher.onError = '
          'onPlatformError;\n'
          '\n'
          '  try {\n'
          '    await Firebase.initializeApp(\n'
          '      options: DefaultFirebaseOptions.currentPlatform,\n'
          '    );\n'
          '  } on Object catch (error, stackTrace) {\n'
          '    onPlatformError(error, stackTrace);\n'
          '  }',
    ),
    // main.dart: restore the session from Firebase instead of the fake.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: 'await InMemoryAuthRepository(store).restoreSession()',
      replacement: 'await firebaseAuthOrFallback(store).restoreSession()',
    ),
    // auth_repository.dart: import the addon repository (ADR 0001).
    AddonPatch(
      file: 'lib/features/auth/data/auth_repository.dart',
      anchor:
          "import 'package:fluframe_app/core/storage/key_value_store.dart';",
      replacement:
          "import 'package:fluframe_app/core/storage/key_value_store.dart';\n"
          "import 'package:fluframe_app/features/auth/data/firebase_auth_repository.dart';",
    ),
    // auth_repository.dart: swap the provider — the single backend seam.
    AddonPatch(
      file: 'lib/features/auth/data/auth_repository.dart',
      anchor:
          '(ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),',
      replacement:
          '(ref) => firebaseAuthOrFallback(ref.watch(keyValueStoreProvider)),',
    ),
  ],
  postCreateNotes: [
    _firebaseSetupNote1,
    _firebaseSetupNote2,
  ],
);

const String _firebaseSetupNote1 =
    'Firebase: run `dart pub global activate flutterfire_cli` then '
    '`flutterfire configure` inside the project (replaces the '
    'lib/firebase_options.dart placeholder). Until you do, the app logs '
    'the configuration error and runs on the in-memory auth fake.';

const String _firebaseSetupNote2 =
    'Firebase: enable Email/Password under Authentication > Sign-in '
    'method in the Firebase console.';

/// All available backend addons, keyed by `--backend` value.
const Map<String, BackendAddon> backendAddons = {
  'firebase': firebaseAddon,
  'supabase': supabaseAddon,
};

/// The Sentry error-reporting addon: wires the crash-reporting seam
/// shipped in the template's `core/logging/error_handlers.dart`.
const BackendAddon sentryAddon = BackendAddon(
  name: 'sentry',
  requiresFiles: false,
  // Pinned: see the note on supabaseAddon's dependencies.
  dependencies: ['sentry_flutter:^9.26.0'],
  patches: [
    // main.dart: run the app INSIDE SentryFlutter.init via appRunner.
    //
    // Without appRunner the SDK never installs RunZonedGuardedIntegration,
    // so zone errors are lost. And anchoring the init above the template's
    // `FlutterError.onError = ...` assignments meant those two lines
    // immediately overwrote the handlers the SDK had just installed —
    // costing the handled/unhandled distinction and crash-free session
    // rate. Anchored on `start();` the order is: template handlers, then
    // Sentry's integrations wrapping them, then runApp inside the
    // guarded zone.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: '  start();',
      replacement:
          "  const sentryDsn = String.fromEnvironment('SENTRY_DSN');\n"
          '  if (sentryDsn.isEmpty) {\n'
          '    start();\n'
          '  } else {\n'
          '    await SentryFlutter.init(\n'
          '      (options) => options.dsn = sentryDsn,\n'
          '      appRunner: start,\n'
          '    );\n'
          '  }',
    ),
    // main.dart: SDK import (sentry_flutter sorts before
    // shared_preferences).
    AddonPatch(
      file: 'lib/main.dart',
      anchor: "import 'package:shared_preferences/shared_preferences.dart';",
      replacement:
          "import 'package:sentry_flutter/sentry_flutter.dart';\n"
          "import 'package:shared_preferences/shared_preferences.dart';",
    ),
    // No error_handlers.dart patches: the SDK's FlutterErrorIntegration
    // and OnErrorIntegration now chain onto the template's handlers, so
    // hand-rolled Sentry.captureException calls would only duplicate
    // every event — and report it as `handled: true`, which is what the
    // manual approach could never get right.

    // env: DSN placeholders.
    AddonPatch(
      file: 'env/dev.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "SENTRY_DSN": ""',
    ),
    AddonPatch(
      file: 'env/prod.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "SENTRY_DSN": ""',
    ),
  ],
  postCreateNotes: [_sentrySetupNote],
);

const String _sentrySetupNote =
    'Sentry: put your DSN in env/dev.local.json (gitignored — copy it from '
    'env/dev.json) as SENTRY_DSN and run with '
    '--dart-define-from-file=env/dev.local.json. With it empty, Sentry '
    'stays disabled.';

/// Error-reporting addons, keyed by `--error-reporting` value.
const Map<String, BackendAddon> errorReportingAddons = {
  'sentry': sentryAddon,
};

/// The Amplitude analytics addon: swaps the analytics seam's provider to
/// a real SDK, guarded on a configured API key.
const BackendAddon amplitudeAddon = BackendAddon(
  name: 'amplitude',
  // Pinned: the injected source uses the 4.x surface
  // (Amplitude(Configuration(...)) + track(BaseEvent(...))); 3.x used
  // Amplitude.getInstance()/logEvent. See supabaseAddon's note.
  dependencies: ['amplitude_flutter:^4.6.2'],
  patches: [
    // analytics_service.dart: import the addon implementation.
    AddonPatch(
      file: 'lib/core/analytics/analytics_service.dart',
      anchor: "import 'package:fluframe_app/core/logging/app_logger.dart';",
      replacement:
          "import 'package:fluframe_app/core/analytics/amplitude_analytics_service.dart';\n"
          "import 'package:fluframe_app/core/logging/app_logger.dart';",
    ),
    // analytics_service.dart: key-guarded provider swap.
    AddonPatch(
      file: 'lib/core/analytics/analytics_service.dart',
      anchor:
          'final analyticsServiceProvider = Provider<AnalyticsService>(\n'
          '  (ref) => const LoggingAnalyticsService(),\n'
          ');',
      replacement:
          'final analyticsServiceProvider = '
          'Provider<AnalyticsService>((ref) {\n'
          '  const amplitudeApiKey = '
          "String.fromEnvironment('AMPLITUDE_API_KEY');\n"
          '  if (amplitudeApiKey.isEmpty) {\n'
          '    return const LoggingAnalyticsService();\n'
          '  }\n'
          '  return AmplitudeAnalyticsService(amplitudeApiKey);\n'
          '});',
    ),
    // env: API key placeholders.
    AddonPatch(
      file: 'env/dev.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "AMPLITUDE_API_KEY": ""',
    ),
    AddonPatch(
      file: 'env/prod.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "AMPLITUDE_API_KEY": ""',
    ),
  ],
  postCreateNotes: [_amplitudeSetupNote],
);

const String _amplitudeSetupNote =
    'Amplitude: put your API key in env/dev.local.json (gitignored — copy '
    'it from env/dev.json) as AMPLITUDE_API_KEY and run with '
    '--dart-define-from-file=env/dev.local.json. With it empty, events go '
    'to the debug log only.';

/// Analytics addons, keyed by `--analytics` value.
const Map<String, BackendAddon> analyticsAddons = {
  'amplitude': amplitudeAddon,
};
