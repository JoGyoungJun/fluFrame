# Handoff — picking this up on another machine

Living document. Update the **State** section when it stops being true;
everything above it is durable setup.

Last updated: **2026-08-09**, after v1.4.1 and the backlog going empty.

---

## 1. Environment setup

The repo needs three things. Only the first is usually missing.

### Flutter SDK — required, and its absence is expensive

**Flutter 3.44+ (Dart 3.12+).** Verify with `fluframe doctor` after
installing, which now compares your Dart version against the template's own
`environment: sdk:` constraint.

The v1.4.0 cycle ran on a machine with **no Flutter and no Dart installed**.
Everything still shipped, because CI is a complete gate — but every check
became a 10–20 minute round-trip instead of a two-second local run, and a
one-character fix cost three of them. If you are doing more than a
documentation change, install the SDK first. `docs/retrospectives/2026-08-v1.4.0.md`
has the full cost accounting.

Without it you **cannot** run: `flutter analyze`, `flutter test`,
`flutter gen-l10n`, `dart analyze`, `dart test`, the e2e, or `/verify`. You
can still work — see "Working without a toolchain" below.

Known-good combination, verified on the Windows dev machine 2026-08-09:
Flutter **3.44.1** stable / Dart **3.12.1**. Note that on Windows the
default-platform e2e still skips locally unless Developer Mode is on —
symlink creation needs it — so Windows regressions are caught by CI, not
by a local `dart test -t e2e`.

### GitHub CLI

`gh` must be installed **and authenticated** (`gh auth status`). Scopes
needed: `repo`, `workflow`, `read:org`.

On Windows the installer adds `gh` to the machine `PATH`, but an already-open
shell will not see it until restarted. Prefix it if so:

```sh
export PATH="/c/Program Files/GitHub CLI:$PATH"   # Git Bash
```

### Git identity

This clone had none — every prior commit was squash-merged through the
GitHub UI, so nothing local was ever authored. Set it repo-locally:

```sh
git config user.name  "JoGyoungJun"
git config user.email "yoop80075@gmail.com"
```

---

## 2. How work happens here

`main` is protected. Every change — maintainers included — goes
branch → PR → all CI jobs green → squash merge. Zero approvals are required,
so self-merging after CI passes is the normal flow:

```sh
git checkout -b fix/<issue#>-<slug>
# ...change, with tests...
gh pr create --fill --milestone <milestone>
gh pr merge <pr> --squash --auto --delete-branch
# then POLL until it reports MERGED — green checks are NOT merged
gh pr view <pr> --json state --jq .state
```

The polling is not optional. v0.7.0 shipped without its headline feature
because a release branched off `main` while the feature PR was still open.

The full routine lives in `.claude/skills/` — `/cycle` runs
plan → work × N → release → retro end to end. `CLAUDE.md` has the hard rules.

### Releasing

Publishing is **automated and irreversible** (retractable only within 7 days).
Do not run `dart pub publish` by hand.

1. Bump `packages/fluframe/pubspec.yaml` `version:` **and**
   `packages/fluframe/lib/src/version.dart` `cliVersion` (a test enforces
   they match), update `CHANGELOG.md`, land it via PR.
2. After that PR reports MERGED: `git tag fluframe-v<version> && git push
   origin fluframe-v<version>`.
3. The tag push triggers `.github/workflows/publish.yml`, which re-runs every
   gate — tag↔pubspec match, unit tests, bundle sync, e2e, dry-run — and
   publishes via OIDC only if all pass. A red gate means the tag exists and
   nothing was published: fix on main, delete and re-push the tag.

---

## 3. Working without a toolchain

Not the current situation — see section 1 — but the constraint returns on
every fresh machine, so this is what the v1.4.0 cycle learned. It is viable.
It is just slow.

- **CI is a strictly stronger gate than `/verify`** — it also runs the
  coverage floors, `example-drift`, the `examples` matrix and the addon
  format check. Open the PR and let it tell you.
- **Check line lengths by hand** before pushing: `awk 'length>80'`.
  `dart format` failures are the single most common CI bounce, and the
  formatter's output for a construct you invented is guesswork. Reuse
  statement shapes that already exist, formatted, in the same file.
- **Generated l10n can be hand-written.** `flutter gen-l10n` output is
  deterministic, and CI regenerates and diffs it, so a hand edit is
  *verified* rather than trusted. A one-string change touches two files per
  app (`app_localizations_<locale>.dart` for the getter,
  `app_localizations.dart` for the `In en, this message translates to` doc
  comment) — times three apps, since both examples carry copies.
- **`dart run tool/check_example_drift.dart --fix` cannot run either**, so
  files that belong in `examples/*/` must be copied by hand. Anything under
  `template/lib` or `template/test` needs a copy in **both** examples, with
  the package name rewritten (`fluframe_app` → `todo_app` / `weather_app`)
  and the import block re-sorted for that name — `directives_ordering` is
  fatal.

---

## 4. State as of 2026-08-09, after v1.4.1

**v1.4.1 is published and the engineering backlog is empty.** Every issue
that existed at the start of the day is closed, and the issue tracker now
has nothing open at all.

That is the fact that should shape the next `/plan`: there is nothing left
to fix, and the project still has 0 stars, 0 external contributors and 3
unique visitors in fourteen days.

### Shipped in v1.4.1

One P0 and five P1 — `#141` (`--fatal-infos` and the lint that cost 10
pub.dev points), `#121` (published bundle has a negative space), `#122`
(bundle download timeouts, and the HTTP half of `bundle_archive` finally
tested), `#123` (`add feature` rollback restores the router and ARBs),
`#124` (the 404 branch covered; coverage floor 72 → 78), `#145` (a
truncated gzip is refused via its CRC32/ISIZE trailer). Plus `#134`,
`dart-lang/setup-dart` → 1.8.0.

**The score recovered: 160/160** for 1.4.1, confirmed after pana
re-analysed. That was what the release was for.

### Landed after v1.4.1, unreleased

`#125` (cache schema guard — in the template, so it reaches existing apps
through `upgrade`), `#126` (`add feature` refuses a name whose tests
exist), `#120` (CI compiles a generated app: Android per push, iOS and
Linux nightly), `#105` (wide-viewport content cap, spec 005), `#158` (no
widget test reaches the network). None of these is urgent enough to
justify a release on its own; they go out with whatever comes next.

**Read the pub.dev score from the pana report, not from `/score`.**
`GET pub.dev/api/packages/fluframe/score` returns a `grantedPoints` that
does not match the package page — it read 150 and then 160 within one
session with nothing published in between. The same API family is
unreliable for release confirmation too: after 1.4.1 published, the
package document's `latest` field still said 1.4.0 while
`/versions/1.4.1` returned 200 and the rendered page said 1.4.1. The
number a visitor actually sees comes from

```sh
curl -s https://pub.dev/api/packages/fluframe/metrics \
  | jq '[.scorecard.panaReport.report.sections[].grantedPoints] | add'
```

Use `/score` only for `downloadCount30Days` and `likeCount`, and read
downloads as CI fetches rather than users (`CLAUDE.md`, "Project goal").

### Backlog

**Empty — literally.** Every issue open at the start of this cycle is
closed and nothing is open now, so the next `/plan` starts from a blank
tracker rather than a queue. Two issues were filed and resolved within the
cycle:

- **#158** — a route test reached the real network and passed only on
  timing. Fixed structurally: `appTestOverrides()` now stubs
  `postsRepositoryProvider`, so no full-app test can reach out.
- **#159** — filed claiming the Gradle `-all` distribution costs every
  user 94 MB, then **closed as wrong before any work was done.**
  `android` is not in `overlayEntries`, so a generated app's wrapper comes
  from `flutter create`, and `-all` is hardcoded in Flutter's own template.
  Editing `template/android/` would change nothing for users. The issue
  keeps the evidence so it is not re-derived.

So the next `/plan` is not choosing between fixes. It is choosing what the
project is for now that the obvious defects are gone.

### Retro action items still open

1. ~~Install Flutter on the dev machine~~ — **done.** The Windows dev machine
   now has Flutter 3.44.1 / Dart 3.12.1, so `/verify` is runnable again and
   section 3 no longer describes the current setup. It stays in this document
   because the constraint recurs on every fresh machine.
2. Loosen `/cycle`'s one-fix-attempt rule to two when `/verify` cannot run
   locally — it was correctly exceeded twice. Still open, and now lower
   priority given (1).

New: **verify an issue's premise before working it, not after.** #159 was
filed by me, with a wrong impact claim, and would have cost a CI cycle on
a change that affects nobody. One `grep overlayEntries` refuted it. The
same check saved #122's "truncated gzip" criterion (the case was not an
error at all — it became #145) and #145's own predicted damage (deletions
where the real damage was an invented merge conflict).

New, from the session that landed the P1 list: **write the acceptance
criteria as claims to be tested, not as outcomes to be assumed.** Two of
the six had a criterion that turned out to be wrong about the code:

- #122 asked for a "truncated gzip" test. Writing it found that the case is
  not an error at all — which became #145.
- #145's own description predicted the damage as "files reported as
  deletions". Measured, it is an invented merge *conflict* on a file the
  user never touched, plus an invitation to `--apply` it.

Both were caught because the test was written before the criterion was
ticked. Neither would have been caught by reading the code.

---

## 5. Traps worth knowing before you touch anything

- **Four rename tokens, not three.** `fluframe_app`, `FluFrame App`,
  `FluFrame 앱`, `FluFrame アプリ`. A test walks `template/lib`,
  `template/test` and `template/AGENTS.md` and fails on any surviving
  fluFrame branding. The CLI's own name is exempt only in three exact shapes
  (`fluframe <subcommand>`, the `fluframe:` scaffold anchors, and
  `.fluframe.json`).
- **Three locales, not two.** `app_en.arb`, `app_ja.arb`, `app_ko.arb`.
  `gen-l10n` falls back to English and only warns, so a missed locale ships
  green — `template/test/l10n/arb_parity_test.dart` is the gate.
- **`.pubignore` patterns stay slash-anchored** (`/test/`, not `test/`). An
  unanchored pattern also strips `templates/app/test` from the published
  bundle. The e2e guards it.
- **`check_example_drift` does not protect what you might assume.**
  `lib/l10n/` is on `intentionallyDivergent`; ARB *keys* and *values* are
  compared separately, and `app_router.dart`, `README.md` and `pubspec.yaml`
  are exempt entirely — an app-shell change must be hand-copied into both
  examples.
- **Generated code is committed** (`*.freezed.dart`, `*.g.dart`,
  `lib/l10n/gen/`). Regenerate and commit with the source change; CI diffs it.
- **`dart analyze` needs `--fatal-infos`** in `packages/fluframe`. Plain
  `dart analyze` exits 0 on infos, and pana scores them — that is exactly how
  v1.4.0 shipped at 150/160.
- **`archive`'s `GZipDecoder` does not raise on a truncated stream.** It
  inflates what it can and returns it, so half a download used to become a
  *partial* archive. Guarded now via the gzip trailer (#145) — but the same
  trap applies anywhere else the package is used, and a `Content-Length`
  check is not enough: a 210-byte stream cut to 209 still inflates fully.
- **Every PR goes `BEHIND` the moment another one merges**, because the
  branch-protection rule is strict. Auto-merge does not update it for you and
  the PR just sits there looking green. `gh pr update-branch <pr>`, then let
  CI re-run. Poll `gh pr view <pr> --json state` until it reports MERGED —
  and check what the poll actually printed, not just its exit code.
- **`dart format`, then check line length by hand anyway.** The formatter
  will not wrap a long string literal or a comment; `awk 'length>80'` will
  tell you and CI will too, one round-trip later.
- **Do not reason about Flutter layout — pump it.** Spec 005's first draft
  was written by reading the widget tree and was wrong four times over:
  moving a cap outside a scroll view's padding narrowed two screens by
  48px; `Center` centres on *both* axes, so it moved content that used to
  start at the top; wrapping a `ListView` makes the window's outer 280px
  stop taking the mouse wheel; and a column inside 24pt padding can never
  reach the cap. Every one was found by a widget test and none by reading.
  Layout assertions should check **offsets, not just widths** — a
  width-only assertion passes for the `Center` version.
- **`android/` is not shipped.** `overlayEntries` is `lib`, `test`, `env`,
  `l10n.yaml`, `analysis_options.yaml`, `README.md`, `AGENTS.md`,
  `pubspec.yaml`, `.gitignore`, `.github` — nothing else. A generated
  app's `android/`, `ios/`, `web/` come from `flutter create`. Changing
  `template/android/**` affects this repo only (see #159).

## 6. Verification notes that are not in the skills

- Coverage floors are ratchets set a few points under the last measurement,
  not targets. Template **78** (measured 82.35), CLI **70** (measured 85.56).
  `ci.yml` carries the reasoning and the history of each number; raise them
  in the same PR that raises coverage.
- On Windows, `dart format`/`git` will rewrite generated files' line endings
  because `core.autocrlf=true`. After `build_runner`, `git status` can show
  a modified `*.freezed.dart` with an empty `git diff` — that is the line
  endings, not drift. Check with `git diff --numstat` before chasing it.
- `dart run tool/check_example_drift.dart` must be run **from
  `packages/fluframe`**, and `template_addons` is at the repo root. Running
  either from the wrong directory fails in a way that reads like a real
  problem.
- Template-only changes still need the e2e: it generates an app from the
  bundle and runs `flutter test` inside it, which is the only place the
  renamed copy of a new test is ever executed.
