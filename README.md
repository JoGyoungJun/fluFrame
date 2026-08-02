# fluFrame

**Production-ready Flutter apps in one command.**

fluFrame is a Flutter boilerplate + CLI: `fluframe create my_app` scaffolds a
feature-first Flutter application with state management, routing, theming,
localization, networking, flavors, strict lints, and tests — already wired
together and passing.

[한국어 README](README.ko.md)

## Quick start

```sh
dart pub global activate fluframe
fluframe create my_app --org com.mycompany
cd my_app
flutter run --dart-define-from-file=env/dev.json
```

Or use this repository as a GitHub template and start from
[`template/`](template/) directly.

## What you get

| Concern | Solution |
|---|---|
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3 — manual `Notifier`/`AsyncNotifier`, no provider codegen |
| Navigation | [go_router](https://pub.dev/packages/go_router) 17 — `StatefulShellRoute` bottom tabs, nested routes |
| Models | [freezed](https://pub.dev/packages/freezed) 3 + json_serializable, sample REST feature |
| Networking | [dio](https://pub.dev/packages/dio) with `DioException` → sealed `ApiException` mapping |
| Persistence | `KeyValueStore` interface over `SharedPreferencesAsync` — trivially fakeable in tests |
| Localization | `flutter gen-l10n` (English + Korean included), no synthetic packages |
| Theming | Material 3 light/dark from one seed color, persisted `ThemeMode` |
| Flavors | `--dart-define-from-file` with `env/dev.json` / `env/prod.json` |
| Lints | [very_good_analysis](https://pub.dev/packages/very_good_analysis) — zero warnings |
| Tests | Unit + widget tests with mocktail and Riverpod overrides — all green out of the box |

## Repository layout

```text
├── template/            # The boilerplate app (fluframe_app) — always compiles, always tested
└── packages/
    └── fluframe/        # The CLI published to pub.dev (fluframe create)
```

The CLI runs `flutter create --empty` on **your** Flutter SDK first — platform
folders always match your installed Flutter version — then overlays the
template's `lib/`, `test/`, and configuration, rewriting package-name tokens.

## Architecture

The template follows a pragmatic feature-first layout:

```text
lib/
├── main.dart            # Bootstrap: load persisted settings before runApp
├── app/                 # MaterialApp.router, GoRouter, themes
├── core/                # config, network, storage, logging, shared widgets
├── features/
│   ├── home/            # Counter demo — sync Notifier
│   ├── posts/           # REST list/detail demo — AsyncNotifier + FutureProvider.family
│   └── settings/        # Theme + language, persisted via KeyValueStore
└── l10n/                # ARB sources + generated localizations
```

Each feature keeps `data/` (repositories), `domain/` (models), and
`presentation/` (controllers + screens) side by side. Screens read
`AsyncValue`s through a shared `AsyncValueWidget` with loading/error/retry
handling built in.

## Development (this repo)

```sh
# Template app
cd template
flutter pub get && flutter gen-l10n
flutter analyze && flutter test

# CLI
cd packages/fluframe
dart pub get
dart analyze && dart test -x e2e   # unit tests
dart test -t e2e                   # full end-to-end (generates a real app)
```

## Contributing

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).
Please open an issue before large changes.

## License

[MIT](LICENSE)
