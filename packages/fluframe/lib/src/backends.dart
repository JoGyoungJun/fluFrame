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

  /// Project-relative path of the file to patch.
  final String file;

  /// Exact string that must be present in the file.
  final String anchor;

  /// Text that replaces the first occurrence of [anchor].
  final String replacement;
}

/// A backend variant applied on top of the base template overlay.
class BackendAddon {
  /// Creates a backend addon definition.
  const BackendAddon({
    required this.name,
    required this.dependencies,
    required this.patches,
    this.postCreateNotes = const [],
  });

  /// Addon identifier (`--backend <name>`, addon directory name).
  final String name;

  /// Packages installed with `flutter pub add`.
  final List<String> dependencies;

  /// Anchored edits applied after the addon files are copied.
  final List<AddonPatch> patches;

  /// Setup steps printed after generation.
  final List<String> postCreateNotes;
}

/// The Supabase auth backend (stage 2 of the backend roadmap).
const BackendAddon supabaseAddon = BackendAddon(
  name: 'supabase',
  dependencies: ['supabase_flutter'],
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
    AddonPatch(
      file: 'lib/main.dart',
      anchor: "import 'package:shared_preferences/shared_preferences.dart';",
      replacement:
          "import 'package:shared_preferences/shared_preferences.dart';\n"
          "import 'package:supabase_flutter/supabase_flutter.dart';",
    ),
    // main.dart: initialize Supabase from --dart-define-from-file config.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: '  WidgetsFlutterBinding.ensureInitialized();',
      replacement:
          '  WidgetsFlutterBinding.ensureInitialized();\n'
          '\n'
          '  await Supabase.initialize(\n'
          "    url: const String.fromEnvironment('SUPABASE_URL'),\n"
          '    publishableKey:\n'
          "        const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),\n"
          '  );',
    ),
    // main.dart: restore the session from Supabase instead of the fake.
    AddonPatch(
      file: 'lib/main.dart',
      anchor: 'await InMemoryAuthRepository(store).restoreSession()',
      replacement: 'await SupabaseAuthRepository().restoreSession()',
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
      replacement: '(ref) => SupabaseAuthRepository(),',
    ),
    // env: placeholder configuration keys.
    AddonPatch(
      file: 'env/dev.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",\n'
          '  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_YOUR-KEY"',
    ),
    AddonPatch(
      file: 'env/prod.json',
      anchor: '"API_BASE_URL": "https://jsonplaceholder.typicode.com"',
      replacement:
          '"API_BASE_URL": "https://jsonplaceholder.typicode.com",\n'
          '  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",\n'
          '  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_YOUR-KEY"',
    ),
  ],
  postCreateNotes: [_supabaseSetupNote],
);

const String _supabaseSetupNote =
    'Supabase: set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in env/dev.json '
    '(and env/prod.json), then enable Email/Password auth in your '
    'Supabase project.';

/// All available backend addons, keyed by `--backend` value.
const Map<String, BackendAddon> backendAddons = {
  'supabase': supabaseAddon,
};
