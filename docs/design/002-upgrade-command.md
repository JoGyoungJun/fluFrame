# 002 — `fluframe upgrade`

- **Status**: APPROVED
- **Issues**: #80 (metadata foundation), #81 (upgrade command) — milestone v0.14.0
- **Date**: 2026-08-03
- **Related**: ADR 0002 (three-way merge strategy)

## 1. Problem

Apps generated at version N are frozen there: every template improvement
since (error hooks, presets, analytics seam...) requires manual porting.
No mainstream Flutter scaffolder solves this — shipping it is a major
differentiator, and 1.0.0 should not freeze an upgrade-less contract.

## 2. Goals / Non-goals

**Goals**: apply template changes to an existing generated app while
preserving user modifications; never destroy work (dry-run default,
git-style conflict markers); support apps generated with any addon combo.
**Non-goals**: upgrading platform folders (flutter's own domain), Dart/
Flutter SDK migration, apps generated before metadata existed without an
explicit `--from`.

## 3. Design

**Metadata (prerequisite, #80)** — `create` writes `.fluframe.json` to
the project root: `{cliVersion, name, org, backend, errorReporting,
analytics}`. `cliVersion` moves to `lib/src/version.dart` (re-exported
from command_runner) so the generator can read it without an import
cycle.

**Upgrade (#81)** — `fluframe upgrade [--apply] [--from <ver>]
[--project-dir <dir>]`:

1. Read `.fluframe.json` (or `--from` for pre-metadata apps; missing
   both → explanatory usage error). Same version → "already up to date".
2. **BASE reconstruction**: download the old package archive from
   pub.dev (`/api/packages/fluframe/versions/<ver>` → `archive_url`,
   .tar.gz via `package:archive`), extract its `templates/`, and run a
   **bare overlay** generation (new generator mode: no flutter create,
   no pub — just overlay + token rewrite + addon patches with the
   recorded addon combo). THEIRS = same bare generation from the current
   bundle. Bare mode keeps BASE/THEIRS structurally identical, so noise
   cancels in the merge.
3. **Three-way merge per file** (THEIRS' file set): theirs==base → skip;
   missing in ours → *added*; else `git merge-file -p ours base theirs`
   → *clean merge* or *conflict* (markers kept, git-familiar). In base
   but not theirs → *removed upstream* (reported, never auto-deleted).
4. Default is a **dry-run report** (counts + per-file classification);
   `--apply` writes results, updates `.fluframe.json` to the new
   version, and prints next steps (`flutter pub get`, `dart fix
   --apply`, `flutter test`).
5. Old-bundle acquisition is injected (`Future<Directory> Function(String
   version)`) so unit tests run offline against local fixture bundles.

## 4. l10n keys

None (CLI-only).

## 5. Test plan

- Unit (fixture bundles, no network): up-to-date short-circuit; added
  file; upstream-changed + locally-unchanged → clean; both-changed →
  conflict markers present; removed-upstream reported; metadata written
  by create and updated by `--apply`; missing metadata without `--from`
  → usage error.
- e2e: generate with the current bundle, locally modify one template
  file, `upgrade --from 0.11.0` (real pub.dev archive) → report lists
  changes; `--apply` leaves the suite green or markers where expected.

## 6. Acceptance criteria

- [ ] `create` writes `.fluframe.json`; `doctor`/docs updated
- [ ] `upgrade` dry-run classifies every file (added / clean / conflict /
      removed / unchanged) with a summary table
- [ ] `--apply` writes clean merges + conflict markers, bumps metadata,
      never deletes files
- [ ] git absent → graceful degradation to report-only with a message
- [ ] Unit suite offline; e2e exercises a real historical version
- [ ] `/release` + CONTRIBUTING updated for `version.dart`

## 7. Open questions

None — deferred: `--to <version>` (upgrade to non-latest), addon
add/remove during upgrade.
