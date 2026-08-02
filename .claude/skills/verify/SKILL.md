---
name: verify
description: Run the full fluFrame verification pipeline — template analyze/test, CLI analyze/format/unit tests, and (unless "fast") the e2e. The single source of truth for "is everything green".
argument-hint: "[fast]"
---

Run the complete verification pipeline for the fluFrame monorepo. This is
the gate before ANY commit, PR merge, or release.

## Steps

1. **Template app** (`template/`):
   ```sh
   cd template
   dart format --set-exit-if-changed lib test
   flutter analyze          # MUST report 0 issues — infos are fatal
   flutter test             # MUST be all green
   ```
2. **Generated-code freshness** (`template/`):
   ```sh
   flutter gen-l10n
   dart run build_runner build --delete-conflicting-outputs
   git status --short -- lib   # MUST be empty — generated code is committed
   ```
   If files changed, the source and generated code were committed out of
   sync — include the regenerated files in the fix.
3. **CLI** (`packages/fluframe/`):
   ```sh
   cd packages/fluframe
   dart format --set-exit-if-changed lib test tool
   dart analyze             # MUST be 0 issues
   dart test -x e2e         # unit tests
   ```
4. **E2E** — skip only when the user passed `fast`:
   ```sh
   dart test -t e2e --reporter expanded
   ```
   The e2e syncs the publish bundle, generates a real app from it, and runs
   `flutter analyze` + `flutter test` inside the generated app (~1-3 min).
   NOTE (Windows): the e2e intentionally uses `android,web` platforms only —
   including `windows` requires Developer Mode for plugin symlinks.

## Reporting

Produce a table: step → PASS/FAIL with counts. On any failure, show the
failing output verbatim and fix it before reporting done — never leave the
repo red. If a `| tail` pipe is used, check the command's real exit code
(pipes swallow it).
