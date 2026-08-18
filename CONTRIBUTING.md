# Contributing to fluFrame

Thanks for your interest in contributing! fluFrame aims to be the fastest way
to start a production-quality Flutter app, and every contribution — bug
reports, docs, translations, code — helps.

## Where to start

New here? The fastest route in:

1. Skim the guides in [docs/](docs/) and the CI workflow — together they
   state the invariants that CI enforces.
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
| `template_addons/` | Optional overlays (`supabase`, `firebase`, `amplitude`) copied into generated apps | `dart` |
| `packages/fluframe/` | The CLI published to pub.dev | `dart` |
| `examples/` | `todo_app` and `weather_app` — generated, then extended | `flutter` |
| `docs/` | Guides, ADRs, versioning policy, comparison | — |
| `.github/` | CI, the release workflow, issue and PR templates | — |

The CI job names on a pull request map onto that table: the
`Template app — …` jobs cover `template/`, the `CLI — …` jobs cover
`packages/fluframe/`, and `Example apps — analyze & test` plus
`Examples — no drift from the template` cover `examples/`.
`template_addons/` has no job of its own — its format gate runs inside
the template job, so an unformatted addon reddens a check named after
something you did not touch.

## Developing the template app

```sh
cd template
flutter pub get
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed lib test
flutter analyze   # must be zero issues
flutter test      # must be all green
```

A template change also has to clear gates that do not live under
`template/`. From the repository root:

```sh
dart format --set-exit-if-changed template_addons

cd packages/fluframe
dart pub get
dart run tool/check_example_drift.dart   # --fix re-syncs what it can
```

- The addon format gate runs in the template CI job because
  `template_addons/` ships verbatim into generated apps — unformatted
  addon code would become the user's red build.
- `check_example_drift.dart` is the job a template change most often
  reddens. `examples/todo_app` and `examples/weather_app` mirror
  `template/`'s `lib/` and `test/` (with the package-name tokens
  rewritten), so a file you touch in one place has to land in three.
  After `--fix`, run the follow-up it prints in each example —
  `dart fix --apply` and `flutter gen-l10n` are not optional there.
- Commit whatever `build_runner` rewrote. CI stages before it diffs
  (`git add -A lib`, then `git diff --cached --exit-code`), so a new
  `.freezed.dart` you forgot to `git add` fails there while your own
  `git diff` looks clean.
- `flutter test --coverage` is gated on a line-coverage floor, as are
  the CLI's unit tests. The numbers live in `.github/workflows/ci.yml`
  and only move upward; deleting a test file is the usual way to trip
  one.

Rules of thumb:

- `very_good_analysis` is the law — CI fails on any analyzer issue.
- Every provider/controller gets a unit test; every screen behavior worth
  keeping gets a widget test.
- All user-facing strings live in **all three** ARBs —
  `lib/l10n/app_en.arb`, `app_ja.arb` and `app_ko.arb` — never hardcode UI
  text. `flutter gen-l10n` falls back to English for a missing key and only
  warns, so a skipped locale ships green; `test/l10n/arb_parity_test.dart`
  is the gate that catches it. If you cannot translate a string, add the
  key with the English value and say so in the PR.
- Keep the `fluframe_app` / `FluFrame App` / `FluFrame 앱` /
  `FluFrame アプリ` tokens intact:
  the CLI rewrites them when generating projects.

## Developing the CLI

```sh
cd packages/fluframe
dart pub get
dart format --set-exit-if-changed lib test tool   # note: tool/ too
dart analyze --fatal-infos   # infos are fatal here too — pana scores them
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
5. If your change moves or renames something a document points at — a
   file path, a command, a flag, a CI job name — update that document in
   the **same PR**. This applies to `README.md` and `docs/`. Those files
   are read occasionally and rot silently between readings: a release
   guide once spent four versions telling a releaser to edit `cliVersion`
   in a file that no longer declared it.

`main` is a protected branch: every change — maintainers' included —
lands through a pull request with all CI jobs green. Nothing merges red.

## Design discussion

- For non-trivial features or hard-to-reverse decisions (core
  dependencies, architecture patterns, the CLI's generation contract),
  open an issue first so the problem, the proposed design, and the
  acceptance criteria are captured before code lands.

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
   prompt). **Read the dry-run file list — do not just run it.** Unlike
   the workflow, this path syncs from your working tree, and
   `packages/fluframe/.gitignore` hides `templates/` from `git status`,
   so the dry-run list is the only place you ever see what is about to be
   uploaded. It must include `templates/app/lib/...`,
   `templates/app/test/...`, and `templates/app/gitignore` — a missing
   `test/` means a `.pubignore` pattern lost its anchoring slash. It must
   include no `*.local.json`, `.env`, key, keystore or credentials file;
   `sync_template.dart` excludes those and exits non-zero if any reach
   the bundle, but this is the check that does not trust the filter.
   When it succeeds, **do not then push the release tag**: a
   `fluframe-v*` tag fires `publish.yml`, which re-runs every gate and
   ends in `dart pub publish --force` against a version pub.dev already
   holds — a red run for a release that succeeded, in a workflow where
   red is supposed to mean nothing was published. You normally reach
   this path because a tag run already failed at its upload step, in
   which case the tag is already on the release commit and there is
   nothing left to push.

### When the tag run fails at the upload step

Step 3 covers a gate failing. There is one failure that is not a gate:
every gate passes, and the run dies at `dart pub publish` with

```text
The calling GitHub Action is not allowed to publish, because: GitHub
repository identifiers changed, disabling automated publishing.
See https://dart.dev/go/publishing-from-github
```

and exit 65. pub.dev pins the GitHub repository's **numeric ID** when
automated publishing is configured, and disables publishing the moment
that ID changes — a repository with the same name and a new ID is
indistinguishable from a takeover, so it is treated as one. This fired on
the `fluframe-v1.6.0` tag: the public repo was created 2026-08-13 as a
clean-tree extraction, while the package had been publishing from a
private predecessor since 0.1.0.

Re-enable automated publishing in the pub.dev admin UI
([the package's Admin tab](https://pub.dev/packages/fluframe/admin)),
then delete and re-push the tag as in step 3. **A failed run publishes
nothing** — every gate runs before the upload, by design, so a failure at
any point leaves the tag carrying no release rather than a half-published
version.
