# fluframe

[![pub package](https://img.shields.io/pub/v/fluframe.svg)](https://pub.dev/packages/fluframe)

Generate production-ready Flutter apps from the
[fluFrame](https://github.com/JoGyoungJun/fluFrame) boilerplate —
Riverpod 3, go_router, localization, theming, dio, and tests wired out
of the box.

**▶ [Try a generated app in your browser](https://jogyoungjun.github.io/fluFrame/)**
— the real thing, nothing installed.

| Home | Sample REST feature | Theming & 3 locales |
|:---:|:---:|:---:|
| <img src="https://raw.githubusercontent.com/JoGyoungJun/fluFrame/main/docs/assets/home-light.png" width="240" alt="Home tab of a generated app"> | <img src="https://raw.githubusercontent.com/JoGyoungJun/fluFrame/main/docs/assets/posts-light.png" width="240" alt="Post list loaded over REST"> | <img src="https://raw.githubusercontent.com/JoGyoungJun/fluFrame/main/docs/assets/settings-dark.png" width="240" alt="Settings tab in dark mode"> |

Straight out of `fluframe create` — no edits.

## Install

**Requires Flutter 3.44 or newer** (Dart 3.12+) — generated apps declare
`sdk: ^3.12.1`.

```sh
dart pub global activate fluframe
```

If `fluframe` is then not found, the pub cache's `bin` is not on your
`PATH`. Add `$HOME/.pub-cache/bin` (macOS/Linux) or
`%LOCALAPPDATA%\Pub\Cache\bin` (Windows) and reopen the terminal.

## Usage

Runnable top to bottom, in this order:

```sh
fluframe doctor                      # check your environment first
fluframe create my_app --org com.mycompany --description "My shiny app"
cd my_app
flutter run --dart-define-from-file=env/dev.json

fluframe add feature billing --tab   # later: scaffold your next feature
fluframe upgrade                     # later: pull template updates in (dry-run)
```

## Adding a feature

`create` runs once; `add feature` runs every time the app grows one:

```sh
fluframe add feature billing          # a full-screen route at /billing
fluframe add feature billing --tab    # ...or a bottom-navigation tab
fluframe add feature billing --dry-run
```

It writes the repository, controller, screen and two tests, registers the
route in `lib/app/router/app_router.dart`, and adds the strings to all
three ARBs — telling you which ones still carry the English text. Then
run `flutter gen-l10n`.

Unlike `upgrade`, it is **not** dry-run by default: it only creates new
files and makes bounded insertions at anchors the template ships. Apps
generated before those anchors existed need `fluframe upgrade` first; the
command says so rather than guessing.

## Why fluframe

Every starter is a snapshot: you generate, and from that moment your app
and the template diverge forever. fluframe is the only Flutter starter we
know of that keeps the connection — `fluframe upgrade` reconstructs the
template as it was at *your* generation version, three-way merges
everything that changed since into your working tree, and reports genuine
conflicts as conflicts instead of guessing. Your edits survive.

That is the reason to pick it, and it is not a reason to pick it over
everything. If your team writes Bloc, or you need a package rather than an
app, [Very Good CLI](https://cli.vgv.dev) is the better tool.
**[docs/comparison.md](https://github.com/JoGyoungJun/fluFrame/blob/main/docs/comparison.md)**
lays both out honestly, including where fluframe loses.

## What you get

- **Riverpod 3** state management — manual `Notifier`/`AsyncNotifier`, no codegen for providers
- **go_router 17** — `StatefulShellRoute` bottom tabs, nested routes
- **freezed 3 + json_serializable** models with a sample REST feature (dio)
- **Typed error handling** — `DioException` mapped to a sealed `ApiException`
- **Localization** — `flutter gen-l10n` with English, Japanese and Korean out of the box
- **Material 3 theming** — light/dark with a persisted `ThemeMode`
- **Persisted settings** — `SharedPreferencesAsync` behind a testable `KeyValueStore`
- **Flavors** — `--dart-define-from-file` with `env/dev.json` / `env/prod.json`
- **Strict lints** — `very_good_analysis`, zero warnings
- **Tests** — unit + widget tests using mocktail and Riverpod overrides

## Options

| Option | Default | Description |
|---|---|---|
| `--org` | `com.example` | Bundle/application identifier organization |
| `--description` | template default | Description for the new `pubspec.yaml` |
| `--output-directory`, `-o` | `.` | Where to create the project folder |
| `--platforms` | all six | Passed through to `flutter create` |
| `--backend` | `none` | Wire a real auth backend (`supabase` \| `firebase`) into the generated app |
| `--error-reporting` | `none` | Wire crash reporting (`sentry`) into the error hooks |
| `--analytics` | `none` | Wire product analytics (`amplitude`) into the analytics seam |
| `--no-pub` | off | Skip `flutter pub get` / `gen-l10n` |

## Exit codes

Every failure is a sentence on stderr and a
[sysexits](https://man.freebsd.org/cgi/man.cgi?sysexits) code — so a
script can branch on what went wrong:

| Code | Name | Meaning |
|---|---|---|
| `0` | `EX_OK` | Success. Dry runs that found work to do exit `0` too |
| `64` | `EX_USAGE` | Bad arguments, or a refusal before anything was written (an invalid name, an app `upgrade` will not touch) |
| `65` | `EX_DATAERR` | `.fluframe.json` is malformed, or holds a value of the wrong type |
| `69` | `EX_UNAVAILABLE` | Something fluframe depends on is not usable: no Flutter on `PATH`, a fatal `doctor` finding, or a template bundle that could not be fetched or verified |
| `70` | `EX_SOFTWARE` | A step did not complete: a failed `flutter` invocation, an `upgrade` that ended with conflict markers still to resolve, or an error fluframe did not expect. The "This is a bug" trace is always this code |
| `74` | `EX_IOERR` | `add feature` had already edited the app and could not put every file back. The message names what to restore |

## How it works

`fluframe create` runs `flutter create --empty` first — so platform folders
always match **your** installed Flutter version — then overlays the fluFrame
application template (`lib/`, `test/`, `l10n.yaml`, `env/`,
`analysis_options.yaml`, `pubspec.yaml`) and rewrites package-name tokens.

## License

MIT
