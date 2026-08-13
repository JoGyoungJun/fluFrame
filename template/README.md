# fluframe_app

A Flutter app generated from the
[fluFrame](https://github.com/JoGyoungJun/fluFrame) boilerplate.

## What's inside

| Concern | Solution |
|---|---|
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3 (manual notifiers, no codegen) |
| Navigation | [go_router](https://pub.dev/packages/go_router) with `StatefulShellRoute` bottom tabs |
| Auth | Backend-neutral `AuthRepository` scaffold — login/profile flow, gated `/profile` route, persisted session; swap in Supabase/Firebase via the [guides](https://github.com/JoGyoungJun/fluFrame/tree/main/docs/guides) |
| Models | [freezed](https://pub.dev/packages/freezed) 3 + json_serializable |
| Networking | [dio](https://pub.dev/packages/dio) with typed `ApiException` mapping |
| Persistence | `KeyValueStore` interface over `SharedPreferencesAsync` |
| Localization | `flutter gen-l10n` (en, ko, ja) — generated into `lib/l10n/gen` |
| Theming | Material 3 light/dark with persisted `ThemeMode` |
| Config | `--dart-define-from-file` flavors (`env/dev.json`, `env/prod.json`) |
| Lints | [very_good_analysis](https://pub.dev/packages/very_good_analysis) |
| Tests | Unit + widget tests with mocktail and Riverpod overrides |
| Staying current | `fluframe upgrade` merges later template versions into this app — see [below](#pulling-in-template-updates) |

## Project structure

```text
lib/
├── main.dart              # Bootstrap: load persisted settings, runApp
├── app/                   # App shell: MaterialApp.router, router, theme
├── core/                  # Cross-cutting: config, network, storage, logging, widgets
├── features/              # Feature-first modules
│   ├── auth/              #   Login/profile flow, gated route (fake repo)
│   ├── home/              #   Counter demo (sync Notifier)
│   ├── posts/             #   REST list/detail demo (AsyncNotifier + FutureProvider)
│   └── settings/          #   Theme + language, persisted
└── l10n/                  # ARB sources and generated localizations
```

Each feature keeps its layers side by side: `data/` (repositories),
`domain/` (models), `presentation/` (controllers + screens).

## Getting started

```sh
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter run --dart-define-from-file=env/dev.json
```

## Common tasks

| Task | Command |
|---|---|
| Run (dev flavor) | `flutter run --dart-define-from-file=env/dev.json` |
| Build (prod flavor) | `flutter build apk --dart-define-from-file=env/prod.json` |
| Run with real keys | `flutter run --dart-define-from-file=env/dev.local.json` — `env/*.json` is committed and holds safe defaults; `env/*.local.json` is gitignored and is where secrets belong |
| Regenerate models | `dart run build_runner build --delete-conflicting-outputs` |
| Regenerate localizations | `flutter gen-l10n` |
| Analyze | `flutter analyze` |
| Test | `flutter test` |

## Adding a feature

```sh
fluframe add feature billing          # a route
fluframe add feature billing --tab    # ...and a bottom-nav tab for it
```

That scaffolds `lib/features/billing/` with `data/`, `domain/` and
`presentation/`, registers the route (and destination) in
`lib/app/router/app_router.dart` at the `// fluframe:routes`,
`// fluframe:branches` and `// fluframe:destinations` anchors, adds the
strings to all three ARBs, and writes the tests. Run `flutter gen-l10n`
afterwards so the new keys get their generated getters.

Do not delete those anchor comments — they are how the command finds its
insertion points.

<details>
<summary>By hand, if you would rather not install the CLI</summary>

1. Create `lib/features/<name>/` with `data/`, `domain/`, `presentation/`.
2. Expose repositories and controllers as Riverpod providers.
3. Register routes in `lib/app/router/app_router.dart`.
4. Add strings to **all three** of `lib/l10n/app_en.arb`, `app_ja.arb` and
   `app_ko.arb`, then run `flutter gen-l10n`. A key missing from one locale
   silently falls back to English — `test/l10n/arb_parity_test.dart` is what
   catches it.
5. Add tests under `test/features/<name>/` — override providers instead of
   mocking widgets.

</details>

## Pulling in template updates

This app was generated from a specific version of fluFrame, recorded in the
`.fluframe.json` at the project root. Keep that file committed: it is how
`fluframe upgrade` knows which version to diff against.

```sh
fluframe upgrade            # dry-run — reports what would change, writes nothing
fluframe upgrade --apply    # actually applies it
```

`upgrade` reconstructs the template as it was at your generation version,
then does a per-file three-way merge against the current one. Your edits
survive. Where both sides changed the same lines you get ordinary git
conflict markers to resolve rather than a guess, and nothing is deleted
without telling you first.

`--apply` requires a git repository with a clean working tree — it refuses
otherwise, so that `git diff` is always a usable way to see what it did.

Two flags worth knowing: `--restore-deleted` brings back template files you
removed, and `--from <version>` sets the base explicitly for apps generated
before `.fluframe.json` existed.
