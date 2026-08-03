# Contributing to fluFrame

Thanks for your interest in contributing! fluFrame aims to be the fastest way
to start a production-quality Flutter app, and every contribution — bug
reports, docs, translations, code — helps.

## Where to start

New here? The fastest route in:

1. Read [docs/architecture.md](docs/architecture.md) — one page, includes
   the invariants that CI enforces.
2. Pick something labeled
   [good first issue](https://github.com/JoGyoungJun/fluFrame/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)
   — each one states its acceptance criteria and exactly which files are
   involved.
3. Generate yourself a playground: `dart run bin/fluframe.dart create
   sandbox -o /tmp` from `packages/fluframe` uses your local checkout.

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
- Keep the `fluframe_app` / `FluFrame App` / `FluFrame 앱` /
  `FluFrame アプリ` tokens intact:
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

## Design specs and ADRs

- Non-trivial features start with a short design spec in
  [`docs/design/`](docs/design/) — problem, design, l10n keys, test
  plan, and testable acceptance criteria. Bug fixes and small tweaks
  skip this.
- Decisions that are hard to reverse (core dependencies, architecture
  patterns, the CLI's generation contract) are recorded as ADRs in
  [`docs/adr/`](docs/adr/). If you are proposing one, open an issue
  first so the discussion is captured.

## Releasing (maintainers)

1. Bump `version` in `packages/fluframe/pubspec.yaml`, `cliVersion` in
   `lib/src/version.dart`, and update `CHANGELOG.md`; land the
   bump on `main` via PR.
2. Push the release tag: `git tag fluframe-v<version> && git push origin
   fluframe-v<version>`. The `publish.yml` workflow re-runs every gate
   (tag↔pubspec match, unit tests, bundle sync, e2e, dry-run) and then
   publishes to pub.dev via OIDC — no local credentials involved.
3. If a gate fails, nothing is published: fix on main via PR, delete and
   re-push the tag.
4. Manual fallback: `packages\fluframe\tool\publish.bat` runs the same
   gates locally, then publishes interactively (`--yes` to skip the
   prompt). The dry-run file list must include `templates/app/lib/...`,
   `templates/app/test/...`, and `templates/app/gitignore` — a missing
   `test/` means a `.pubignore` pattern lost its anchoring slash.
