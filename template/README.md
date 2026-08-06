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

1. Create `lib/features/<name>/` with `data/`, `domain/`, `presentation/`.
2. Expose repositories and controllers as Riverpod providers.
3. Register routes in `lib/app/router/app_router.dart`.
4. Add strings to `lib/l10n/app_en.arb` (+ translations) and run `flutter gen-l10n`.
5. Add tests under `test/features/<name>/` — override providers instead of mocking widgets.
