# fluframe

[![pub package](https://img.shields.io/pub/v/fluframe.svg)](https://pub.dev/packages/fluframe)

Generate production-ready Flutter apps from the
[fluFrame](https://github.com/JoGyoungJun/fluFrame) boilerplate —
Riverpod 3, go_router, localization, theming, dio, and tests wired out
of the box.

## Install

```sh
dart pub global activate fluframe
```

## Usage

```sh
fluframe doctor                      # check your environment first
fluframe create my_app --org com.mycompany --description "My shiny app"
cd my_app
flutter run --dart-define-from-file=env/dev.json
```

## What you get

- **Riverpod 3** state management — manual `Notifier`/`AsyncNotifier`, no codegen for providers
- **go_router 17** — `StatefulShellRoute` bottom tabs, nested routes
- **freezed 3 + json_serializable** models with a sample REST feature (dio)
- **Typed error handling** — `DioException` mapped to a sealed `ApiException`
- **Localization** — `flutter gen-l10n` with English and Korean out of the box
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

## How it works

`fluframe create` runs `flutter create --empty` first — so platform folders
always match **your** installed Flutter version — then overlays the fluFrame
application template (`lib/`, `test/`, `l10n.yaml`, `env/`,
`analysis_options.yaml`, `pubspec.yaml`) and rewrites package-name tokens.

## License

MIT
