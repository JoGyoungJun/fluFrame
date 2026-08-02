# Contributing to fluFrame

Thanks for your interest in contributing! fluFrame aims to be the fastest way
to start a production-quality Flutter app, and every contribution — bug
reports, docs, translations, code — helps.

## Ground rules

- Be kind. We follow the [Code of Conduct](CODE_OF_CONDUCT.md).
- Open an issue before starting large changes so we can align first.
- Keep the template **opinionated but minimal**: every added dependency or
  abstraction must earn its place. When in doubt, leave it out.

## Repository layout

| Path | What it is | Toolchain |
|---|---|---|
| `template/` | The boilerplate Flutter app (`fluframe_app`) | `flutter` |
| `packages/fluframe/` | The CLI published to pub.dev | `dart` |

## Developing the template app

```sh
cd template
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
flutter analyze   # must be zero issues
flutter test      # must be all green
```

Rules of thumb:

- `very_good_analysis` is the law — CI fails on any analyzer issue.
- Every provider/controller gets a unit test; every screen behavior worth
  keeping gets a widget test.
- All user-facing strings live in `lib/l10n/app_en.arb` **and**
  `app_ko.arb` — never hardcode UI text.
- Keep the `fluframe_app` / `FluFrame App` / `FluFrame 앱` tokens intact:
  the CLI rewrites them when generating projects.

## Developing the CLI

```sh
cd packages/fluframe
dart pub get
dart analyze
dart test -x e2e   # fast unit tests
dart test -t e2e   # full pipeline: generates a real app, analyzes and tests it
```

The e2e test requires the Flutter SDK on PATH and takes a few minutes.

## Pull requests

1. Fork, create a branch, make your change.
2. Run the full verification for whatever you touched (see above).
3. Use [Conventional Commits](https://www.conventionalcommits.org/) with a
   scope, e.g. `feat(template): add golden test setup`,
   `fix(cli): handle spaces in output path`.
4. Describe **what** and **why** in the PR body; link the related issue.

`main` is a protected branch: every change — maintainers' included —
lands through a pull request with all CI jobs green. Nothing merges red.

## Releasing (maintainers)

1. Bump `version` in `packages/fluframe/pubspec.yaml`, `cliVersion` in
   `lib/src/command_runner.dart`, and update `CHANGELOG.md`.
2. `cd packages/fluframe && dart run tool/sync_template.dart`
3. `dart test -t e2e` — the e2e generates from the synced bundle and fails
   if the bundle is incomplete.
4. `dart pub publish --dry-run` — verify the file list includes
   `templates/app/lib/...`, `templates/app/test/...`, and
   `templates/app/gitignore`. A missing `test/` means an ignore pattern
   regressed (they must stay slash-anchored in `.pubignore`).
5. `dart pub publish`
