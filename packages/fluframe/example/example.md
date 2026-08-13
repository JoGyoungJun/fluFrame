# fluframe in 60 seconds

Requires Flutter 3.44 or newer (Dart 3.12+).

Install the CLI once:

```sh
dart pub global activate fluframe
```

If `fluframe` is not found afterwards, add the pub cache's `bin` to your
`PATH` — `$HOME/.pub-cache/bin` on macOS/Linux,
`%LOCALAPPDATA%\Pub\Cache\bin` on Windows — and reopen the terminal.

Create a production-ready Flutter app:

```sh
fluframe create my_app \
  --org com.mycompany \
  --description "My shiny app"
```

Run it:

```sh
cd my_app
flutter run --dart-define-from-file=env/dev.json
```

You now have a feature-first Flutter app with Riverpod 3, go_router
bottom tabs, freezed models, a dio REST sample, English, Japanese and
Korean localization, persisted dark mode, flavors, strict lints — and a test
suite that is already green:

```sh
flutter analyze   # 0 issues
flutter test      # all green
```

## Useful options

```sh
fluframe create my_app -o projects/        # create inside a directory
fluframe create my_app --platforms android,ios,web
fluframe create my_app --no-pub            # skip pub get / gen-l10n
fluframe --version
```
