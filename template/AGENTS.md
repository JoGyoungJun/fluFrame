# AGENTS.md

Conventions for coding agents working in **FluFrame App** (package
`fluframe_app`). This app enforces its rules with lints and CI, so a change
that ignores them fails the build even when it runs fine locally.

## Verify after every change

```sh
flutter analyze   # must report 0 issues — infos are fatal here
flutter test      # must be all green
dart format lib test
```

`.github/workflows/ci.yml` runs `pub get` → `gen-l10n` → `analyze` → `test`
on every pull request. Run the same commands before you say you are done.

## Layout is feature-first

```text
lib/
├── main.dart      # Bootstrap, then runApp
├── app/           # App shell: MaterialApp.router, router, theme
├── core/          # Cross-cutting: config, network, storage, logging, widgets
├── features/      # One directory per feature
│   └── <feature>/
│       ├── data/          # Repositories, data sources
│       ├── domain/        # Models (freezed) and pure logic
│       └── presentation/  # Controllers (Riverpod) and screens
└── l10n/          # ARB sources + generated localizations
```

Put new code in the feature that owns it, not in `core/`. `core/` is for
things at least two features already use; a helper written for one feature
belongs beside that feature. Features do not import each other's `data/` or
`presentation/` — go through a provider, or lift the shared piece to `core/`.

Tests mirror the source tree: `lib/features/posts/...` is tested by
`test/features/posts/...`.

## Every user-visible string goes through l10n

Never hardcode display text in a widget. For each new string:

1. Add the key **and a `@key` description** to `lib/l10n/app_en.arb`.
2. Add the same key to `lib/l10n/app_ko.arb` **and** `lib/l10n/app_ja.arb`.
   A key missing from one locale is a runtime fallback to English, which no
   test catches.
3. Run `flutter gen-l10n` and commit the regenerated `lib/l10n/gen/`.

Read strings via `AppLocalizations.of(context)` — screens usually bind it
once as `final l10n = AppLocalizations.of(context);`. Widget tests must pump
through `tester.pumpApp`, which installs the localization delegates; a plain
`pumpWidget` throws as soon as the widget looks a string up.

## State: Riverpod 3, manual notifiers, no provider codegen

There is deliberately **no `riverpod_generator`**. Write providers by hand:

```dart
/// The counter shown on the home screen.
class CounterController extends Notifier<int> {
  @override
  int build() => 0;

  /// Increments the counter by one.
  void increment() => state = state + 1;
}

/// Provider for the home screen counter.
final counterProvider = NotifierProvider<CounterController, int>(
  CounterController.new,
);
```

- `Notifier` for synchronous state, `AsyncNotifier` for anything that loads.
- Family arguments go to the **notifier's constructor**, not to `build()`.
- Types like `Override`, `ProviderFamily` and `FutureProviderFamily` come
  from `package:flutter_riverpod/misc.dart`; `hasError` / `valueOrNull` are
  extension members, so the file using them must import
  `package:flutter_riverpod/flutter_riverpod.dart` itself.
- `StateProvider`, `StateNotifierProvider` and friends live in
  `package:flutter_riverpod/legacy.dart`. Do not use them in new code.
- Tests build containers with `createContainer(overrides: [...])` from
  `test/helpers/helpers.dart` and override the repository provider with a
  fake. That helper exists because Riverpod 3 retries failed providers
  automatically; a raw `ProviderContainer` makes error-path tests flake.
  Widget tests use `tester.pumpApp(widget)` from the same file, which
  supplies the `ProviderScope` and the localization delegates.

## Lints: very_good_analysis, infos are fatal

- Every **public** member needs a `///` doc comment.
- Anything under `lib/` is imported as `package:fluframe_app/...`, never
  relatively, in one alphabetically sorted block —
  `always_use_package_imports` and `directives_ordering` are both enforced.
  (Test-only helpers may be imported relatively, as `test/` already does.)
- Lines wrap at 80 characters.
- Run `dart format lib test`; unformatted code is a review comment at best
  and a CI failure once you add the format step.
- Comments explain **why**, not what. Prefer no comment to a restatement of
  the line below it.

## Generated code is committed

`*.freezed.dart`, `*.g.dart` and `lib/l10n/gen/` are checked in, so a fresh
clone builds without running codegen first. That only holds if you keep them
in sync: after editing a freezed model or a `@JsonSerializable` class, run

```sh
dart run build_runner build --delete-conflicting-outputs
```

and commit the regenerated files **in the same change** as the source. Never
hand-edit a generated file — the next build overwrites it.

Model classes are freezed 3 style: `abstract class Post with _$Post` (or
`sealed`). Prefer Dart `switch` patterns over the legacy `when` / `map`.

## Config and flavors

Runtime configuration comes from `--dart-define-from-file`, read through
`String.fromEnvironment` constants in `lib/core/config/app_config.dart`:

```sh
flutter run --dart-define-from-file=env/dev.json
flutter build apk --dart-define-from-file=env/prod.json
```

- `env/dev.json` and `env/prod.json` are **committed** and hold safe,
  non-secret defaults.
- Real keys go in `env/dev.local.json` / `env/prod.local.json`, which
  `.gitignore` excludes. Never put a secret in a committed `env/*.json`, in
  Dart source, or in a test fixture.
- Add a new setting by adding the key to *both* committed env files and a
  matching `String.fromEnvironment` constant with a working default — the app
  must still run with no `--dart-define-from-file` flag at all.

## Adding a feature

`fluframe add feature <name> [--tab]` scaffolds all of the below — the
directories, a repository and controller, the route (and destination), the
strings in all three ARBs, and the tests. Prefer it: it cannot forget a
locale or an anchor. Run `flutter gen-l10n` afterwards.

It finds its insertion points at the `// fluframe:routes`,
`// fluframe:branches` and `// fluframe:destinations` comments in
`lib/app/router/app_router.dart`. Leave them in place.

By hand, the same shape:

1. `lib/features/<name>/{data,domain,presentation}/` with the layers it
   actually needs.
2. Repository as an interface plus an implementation, exposed via a provider
   so tests can override it.
3. Controller as a `Notifier` / `AsyncNotifier`; screens read it with
   `ref.watch`.
4. Register the route in `lib/app/router/app_router.dart`.
5. Strings into all three ARBs, then `flutter gen-l10n`.
6. Tests under `test/features/<name>/`: controller unit tests with a fake
   repository, plus a widget test for the screen.
7. `flutter analyze && flutter test`.
