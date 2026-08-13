---
name: verify
description: Run the full fluFrame verification pipeline — template format/analyze/test, codegen freshness, addon + CLI format/analyze/unit tests, example drift, and (unless "fast") the e2e. Mirrors every gate CI enforces.
argument-hint: "[fast]"
---

Run the complete verification pipeline for the fluFrame monorepo. This is
the gate before ANY commit, PR merge, or release.

Every step below maps to a job in `.github/workflows/ci.yml`, so a green run
here means a green PR. When a gate is added to CI, add it here in the same
PR — a `/verify` that is a subset of CI is worse than no `/verify`, because
it promises a green PR it cannot deliver.

## Steps

1. **Template app** (`template/`):
   ```sh
   cd template
   dart format --set-exit-if-changed lib test
   flutter analyze          # MUST report 0 issues — infos are fatal
   flutter test --coverage  # MUST be all green
   ```
   CI job `Template app — analyze & test` also floors line coverage at
   **78%** and format-checks the addon sources, which the command above does
   not reach. From the repo root:
   ```sh
   dart format --set-exit-if-changed template_addons
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
   dart analyze --fatal-infos   # MUST be 0 issues — infos included
   dart test -x e2e         # unit tests
   ```
   CI job `CLI — analyze & unit tests` floors CLI line coverage at **70%**,
   and `CLI — unit tests on ${{ matrix.os }}` re-runs the unit tests on
   macOS and Windows.
4. **Examples** — a `template/lib` or `template/test` change that is not
   re-synced fails CI after a completely green 1-3. Jobs
   `Examples — no drift from the template` and
   `Example apps — analyze & test`:
   ```sh
   cd packages/fluframe
   dart run tool/check_example_drift.dart        # --fix re-syncs, then re-run
   cd ../../examples/todo_app    && flutter pub get && flutter analyze && flutter test
   cd ../weather_app             && flutter pub get && flutter analyze && flutter test
   ```
   The examples set `generate: true` and CI has no codegen-freshness step for
   them, so run `flutter gen-l10n` in each and commit the output deliberately
   after any ARB change — a forgotten commit goes green in CI while the repo
   carries stale files.
5. **E2E** — skip only when the user passed `fast`:
   ```sh
   dart test -t e2e --reporter expanded
   ```
   Five cases (`test/create_e2e_test.dart`): baseline;
   supabase + sentry + amplitude; firebase; the shipped default platform set;
   and `add feature --tab`. Each syncs the publish bundle, generates a real
   app and runs `flutter analyze` (four also run `flutter test`).
   `dart_test.yaml` allows **15 minutes per e2e test** — budget tens of
   minutes, not the ~1-3 this file used to claim.

   NOTE (Windows): four of the five cases pin `platforms: ['android','web']`,
   because `windows`/`linux` need Developer Mode for plugin symlinks. The
   fifth deliberately uses the full default set and **skips itself** when
   `canCreateSymlink()` is false — so on Windows without Developer Mode it
   does not run, and the shipped platform set is only covered by CI.

## Reporting

Produce a table: step → PASS/FAIL with counts. On any failure, show the
failing output verbatim and fix it before reporting done — never leave the
repo red. If a `| tail` pipe is used, check the command's real exit code
(pipes swallow it).
