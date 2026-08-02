# fluFrame — Flutter Boilerplate + CLI

Monorepo for **fluFrame**: a production-ready Flutter app template and the
`fluframe` CLI (pub.dev) that generates projects from it.

## Layout

| Path | What | Toolchain |
|---|---|---|
| `template/` | Boilerplate app, package name `fluframe_app` | `flutter` (3.44+) |
| `packages/fluframe/` | CLI: `fluframe create <name>` | `dart` |
| `_backup-ccgs/` | Unrelated backup of a game-studio template — ignore | — |

## Maintenance commands (.claude/skills/)

| Command | Purpose |
|---|---|
| `/verify [fast]` | Full verification pipeline — the gate before any commit/release |
| `/upgrade-deps [major]` | Safe dependency/SDK upgrades with breaking-change research |
| `/release <version>` | pub.dev release: bump → sync → e2e → dry-run audit → publish → tag |
| `/new-feature <name>` | Add a template feature module following all conventions |
| `/stack-watch` | Re-ground pinned versions & post-cutoff notes against reality |
| `/oss-triage` | Issues/PRs triage, CI health, adoption metrics vs Claude for OSS goals |

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
  project name, `FluFrame App` → humanized title, and `FluFrame 앱` →
  humanized title + ` 앱`. These tokens must keep appearing exactly in
  `template/pubspec.yaml`, package imports, and both ARB `appTitle`s.
- **`.pubignore` patterns stay slash-anchored** (`/test/`, not `test/`) —
  an unanchored pattern also strips `templates/app/test` from the published
  bundle. The e2e test and release checklist guard this.
- **All UI strings via l10n** — add to BOTH `template/lib/l10n/app_en.arb`
  and `app_ko.arb`, then `flutter gen-l10n`.
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

Grow this into an OSS project meeting Anthropic's **Claude for OSS** program
criteria (500+ dependent repos, or 200k+ monthly downloads, or 20+ external
contributors in 12 months). Prioritize: pub.dev quality score, docs quality,
contributor-friendliness, and real-world usefulness of generated apps.
