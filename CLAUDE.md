# fluFrame — Flutter Boilerplate + CLI

Monorepo for **fluFrame**: a production-ready Flutter app template and the
`fluframe` CLI (pub.dev) that generates projects from it.

## Layout

| Path | What | Toolchain |
|---|---|---|
| `template/` | Boilerplate app, package name `fluframe_app` | `flutter` (3.44+) |
| `packages/fluframe/` | CLI: `fluframe create <name>` | `dart` |
| `_backup-ccgs/` | Unrelated backup of a game-studio template — ignore | — |

**Starting on a new machine, or resuming after a break?** Read
[`docs/handoff.md`](docs/handoff.md) first — required toolchain, the branch
and release flow, where the work currently stands, and the traps that have
already cost a release.

## Development routine (.claude/skills/)

GitHub-native port of a structured dev methodology: issues are the unit
of work, milestones are the plan of record.

```text
idea → issue → /design (spec) ± /adr (decision) → /plan (milestone)
     → /work <issue#> → branch → tests → PR + CI gate → merge
     → /release <version> → /oss-triage ↺ → /retro (per milestone)

/cycle = the whole loop in one command (plan → work × N → release → retro)
```

| Command | Purpose |
|---|---|
| `/cycle [milestone]` | One full cycle end-to-end; pauses only at plan approval & publish |
| `/plan [milestone]` | Milestone planning: goal, prioritized issues, P0 readiness gate |
| `/design <title\|issue#>` | Design spec before non-trivial changes → `docs/design/` |
| `/adr <title>` | Architecture Decision Record → `docs/adr/` |
| `/work <issue#>` | Issue-driven implementation: readiness gate → branch → tests → PR |
| `/verify [fast]` | Full verification pipeline — the gate before any commit/release |
| `/new-feature <name>` | Template feature module conventions (used by /work) |
| `/release <version>` | pub.dev release: bump → sync → e2e → dry-run audit → publish → tag |
| `/retro [milestone]` | Milestone retrospective: plan-vs-actual, 3-5 owned action items |
| `/upgrade-deps [major]` | Safe dependency/SDK upgrades with breaking-change research |
| `/stack-watch` | Re-ground pinned versions & post-cutoff notes against reality |
| `/oss-triage` | Issues/PRs triage, CI health, adoption metrics vs Claude for OSS goals |

## Branch workflow

`main` is protected — every change (maintainers included) lands via
branch → PR → all three CI jobs green → merge. Direct pushes to main are
rejected. Zero approvals are required, so self-merging your own PR after
CI passes is the normal flow: `gh pr create --fill` then
`gh pr merge --squash --auto --delete-branch`.

## Verification (run after ANY change)

```sh
# template/
flutter analyze     # must be 0 issues (very_good_analysis, infos are fatal)
flutter test        # must be all green

# packages/fluframe/
dart analyze && dart test -x e2e
dart test -t e2e    # full pipeline — run before releases and CLI changes
```

## Hard rules

- **Never break the rename tokens.** The CLI rewrites `fluframe_app` →
  project name, `FluFrame App` → humanized title, `FluFrame 앱` →
  humanized title + ` 앱`, and `FluFrame アプリ` → humanized title +
  ` アプリ`. These tokens must keep appearing exactly in
  `template/pubspec.yaml`, package imports, and every ARB `appTitle`.
- **`.pubignore` patterns stay slash-anchored** (`/test/`, not `test/`) —
  an unanchored pattern also strips `templates/app/test` from the published
  bundle. The e2e test and release checklist guard this.
- **All UI strings via l10n** — add to ALL THREE ARBs
  (`template/lib/l10n/app_en.arb`, `app_ja.arb`, `app_ko.arb`), then
  `flutter gen-l10n`. A missing key silently falls back to English;
  `template/test/l10n/arb_parity_test.dart` is what fails instead.
- **Generated code is committed** (`*.freezed.dart`, `*.g.dart`,
  `lib/l10n/gen/`) so cloned/generated apps work without codegen. Regenerate
  and commit together with source changes.
- **Import style**: package imports (`package:fluframe_app/...`), one sorted
  block — `directives_ordering` is enforced. The CLI runs `dart fix --apply`
  post-rename because renaming changes sort order.
- Keep the template dependency-light; new dependencies need strong
  justification.

## Post-knowledge-cutoff API notes (verified 2026-08-02)

- **Riverpod 3**: `Override`, `FutureProviderFamily`, `ProviderFamily` etc.
  come from `package:flutter_riverpod/misc.dart` (not the main lib).
  `hasError`/`valueOrNull` are extension members — the using file must import
  `flutter_riverpod.dart` itself. Tests use `ProviderContainer.test(...)` and
  disable auto-retry with `retry: (count, error) => null`. Family arg goes to
  the notifier **constructor**, not `build()`. Legacy `StateProvider` & co.
  live in `flutter_riverpod/legacy.dart` — do not use in new code.
- **freezed 3**: model classes must be `abstract class X with _$X` (or
  `sealed`). Prefer Dart `switch` patterns over legacy `when`/`map`.
  freezed 3.2.x conflicts with build_runner ≥2.15.2 (analyzer bounds) —
  build_runner is pinned `^2.15.1`.
- **Flutter 3.44**: `withOpacity` → `withValues(alpha:)`; component themes
  use `*ThemeData` classes (`AppBarThemeData`, `CardThemeData`);
  `MaterialState*` → `WidgetState*`; `WillPopScope` → `PopScope`;
  Radio needs `RadioGroup` (template uses `SegmentedButton` instead);
  l10n synthetic package (`package:flutter_gen`) is REMOVED — generated
  files live in `lib/l10n/gen/` (see `l10n.yaml`).
- `flutter analyze` treats infos as fatal — zero-tolerance.

## Release (CLI to pub.dev)

See CONTRIBUTING.md "Releasing". Short version: bump versions (pubspec +
`cliVersion`), `dart run tool/sync_template.dart`, `dart pub publish --dry-run`,
publish. The bundled `templates/app` is gitignored but published via
`.pubignore`.

## Project goal

Grow this into an OSS project worth depending on. Anthropic's **Claude for
OSS** program is the yardstick. Its eligibility tracks, read from
<https://claude.com/contact-sales/claude-for-oss> on 2026-08-09:

| Track | Threshold | Reachable here? |
|---|---|---|
| Maintainers / library authors | 500+ dependent repos, 100+ dependent packages, **or** 200k+ combined monthly downloads | downloads only — see below |
| Core contributors | listed committer on CPython, Rust, Node.js TSC, Apache PMC, CNCF, Kubernetes, Linux, Django, Rails "or similar" | not through this repo |
| Active contributors | 100+ PRs merged into repos you do not own, last 12 months | **yes — and independent of fluFrame's adoption** |
| Community builders | 20+ unique external contributors with merged PRs, last 12 months | yes, but downstream of discovery |
| Critical infrastructure | OpenSSF criticality score ≥ 0.4 | not yet |

There is also an explicit door for everything else: *"If you maintain
something the ecosystem quietly depends on, apply anyway and tell us about
it."*

**Two of these are structurally zero, not merely far away.** A generated app
contains no reference to `fluframe` in any manifest — `template/pubspec.yaml`
is `publish_to: none` with no fluframe entry — and both dependent-repo and
dependent-package counts are computed from committed manifests.
`pub.dev/packages?q=dependency:fluframe` returns 0 packages, and will still
return 0 after the thousandth user. Do not plan work against them. The one
change that would make them capable of being non-zero is shipping `fluframe`
as a `dev_dependency` of the generated app — a real design question that must
justify itself on its own merits, not a metrics lever.

**Downloads are not a user count.** pub.dev counts archive fetches, and its
own scoring docs warn the number "can be highly affected if the package is
used by CI systems". Treat it as an indicator, never as evidence that people
are using the CLI.

Prioritize: pub.dev quality score, docs quality, contributor-friendliness,
and real-world usefulness of generated apps. None of those move adoption on
their own — discovery needs a human posting a link, and a milestone that
implies growth through engineering alone is a milestone that will miss.
