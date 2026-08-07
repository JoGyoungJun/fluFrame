# fluFrame

[![CI](https://github.com/JoGyoungJun/fluFrame/actions/workflows/ci.yml/badge.svg)](https://github.com/JoGyoungJun/fluFrame/actions/workflows/ci.yml)
[![pub package](https://img.shields.io/pub/v/fluframe.svg)](https://pub.dev/packages/fluframe)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Production-ready Flutter apps in one command.**

fluFrame is a Flutter boilerplate + CLI: `fluframe create my_app` scaffolds a
feature-first Flutter application with state management, routing, theming,
localization, networking, flavors, strict lints, and tests — already wired
together and passing.

**▶ [Try a generated app in your browser](https://jogyoungjun.github.io/fluFrame/)**
— the real thing, nothing installed.

[한국어 README](README.ko.md)

| Home | Sample REST feature | Theming & 3 locales |
|:---:|:---:|:---:|
| <img src="docs/assets/home-light.png" width="240" alt="Home tab of a generated app"> | <img src="docs/assets/posts-light.png" width="240" alt="Post list loaded over REST"> | <img src="docs/assets/settings-dark.png" width="240" alt="Settings tab in dark mode"> |

Straight out of `fluframe create` — no edits.

## Quick start

```sh
dart pub global activate fluframe
fluframe doctor    # first: confirm this machine can build Flutter apps
fluframe create my_app --org com.mycompany --backend supabase
cd my_app
flutter run --dart-define-from-file=env/dev.json

fluframe upgrade   # later: pull template improvements into your app
```

Post-1.0 stability promises are documented in
[docs/versioning.md](docs/versioning.md).

Or use this repository as a GitHub template and start from
[`template/`](template/) directly.

## Why fluFrame

Every starter is a snapshot: you generate, and from that moment your app
and the template diverge forever. fluFrame is the only Flutter starter we
know of that keeps the connection — `fluframe upgrade` reconstructs the
template as it was at *your* generation version, three-way merges
everything that changed since into your working tree, and reports genuine
conflicts as conflicts instead of guessing. Your edits survive.

That is the reason to pick it, and it is not a reason to pick it over
everything. If your team writes Bloc, or you need a package rather than an
app, [Very Good CLI](https://cli.vgv.dev) is the better tool.
**[docs/comparison.md](docs/comparison.md)** lays both out honestly,
including where fluFrame loses.

## What you get

| Concern | Solution |
|---|---|
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) 3 — manual `Notifier`/`AsyncNotifier`, no provider codegen |
| Navigation | [go_router](https://pub.dev/packages/go_router) 17 — `StatefulShellRoute` bottom tabs, nested routes |
| Auth | Backend-neutral scaffold: login/profile flow, gated routes, persisted session — swap in [Supabase](docs/guides/auth-supabase.md) or [Firebase](docs/guides/auth-firebase.md) via one provider |
| Models | [freezed](https://pub.dev/packages/freezed) 3 + json_serializable, sample REST feature |
| Networking | [dio](https://pub.dev/packages/dio) with `DioException` → sealed `ApiException` mapping |
| Persistence | `KeyValueStore` interface over `SharedPreferencesAsync` — trivially fakeable in tests |
| Localization | `flutter gen-l10n` (English, Japanese and Korean included), no synthetic packages |
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

## Examples

Real apps generated with `fluframe create` and extended by the book:

- [`examples/todo_app`](examples/todo_app) — persisted todo list added as
  a new feature module + tab (freezed, KeyValueStore, AsyncNotifier,
  l10n, tests)
- [`examples/weather_app`](examples/weather_app) — current weather from a
  keyless public API (Open-Meteo): absolute-URL dio calls,
  FutureProvider.family, city picker

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
