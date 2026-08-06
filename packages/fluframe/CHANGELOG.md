# Changelog

## Unreleased

- **Fixed: `upgrade --apply` corrupted non-ASCII source files.** Child
  process output was decoded with the OS codepage (cp949 on Korean
  Windows, cp932 on Japanese), so a merged `find.text('한국어')` came back
  as `find.text('?쒓뎅??` — closing quote and all. Every process the CLI
  launches now decodes as UTF-8, and `git merge-file` writes its result to
  a file instead of stdout so the merged bytes never cross a pipe. The
  damage was silent: the run reported `conflicts: 0` and exited 0.
- **Fixed: a failed merge could blank a file.** A hard `git merge-file`
  error (binary input, unreadable file) produced empty output that was
  written over the user's copy. Such files are now reported and left
  untouched.
- **Fixed: unresolved conflicts sealed off the re-run.** `--apply` bumped
  `.fluframe.json` to the new version even with conflict markers still in
  the tree, so the next run answered `nothing to upgrade` and the only way
  out was hand-editing the metadata. The recorded version now advances
  only on a clean result, and a run with conflicts exits non-zero.
- **Added: `--apply` refuses when it could not be undone.** It keeps no
  backup and `flutter create` does not `git init`, so it now requires a
  git repository with a clean working tree. `fluframe upgrade --apply
  --force` opts out. The check runs before the bundle download, not after.
- CLI unit tests also run on Windows and macOS in CI.

## 1.1.0

- Template: the settings **language picker no longer clips its labels on
  phone-width screens**. Four segments plus a selected-state check icon
  overflowed a 390pt viewport, wrapping "English" mid-word; the picker now
  uses the same wrapping chips as the theme-colour section. Regression test
  pins the labels to a single line at phone width.
- Template: `go_router` moved to `^17.4.0`, and the committed lockfiles
  (template and both examples) were refreshed — this drops the **retracted
  `build_daemon` 4.1.3** that generated apps previously inherited, and picks
  up `built_value` 8.12.7.
- Docs: README (English and Korean) and the pub.dev page now show
  screenshots of a generated app — home, the sample REST feature, and the
  settings tab in dark mode.

## 1.0.0

**Stability declaration** — fluframe now follows semantic versioning
against a documented public contract (see `docs/versioning.md` in the
repository): CLI surface, generation guarantees, rename tokens,
`.fluframe.json` schema, the stackable addon mechanism, and the upgrade
path.

- **`fluframe upgrade [--apply] [--from]`** — pull template updates into
  an existing app via a per-file three-way merge (base reconstructed
  from the pub.dev archive of the version the app was generated with);
  dry-run by default, git conflict markers, removals reported but never
  auto-deleted.
- `create` now records generation metadata (`.fluframe.json`, schema 1:
  version + addon combo) — the contract `upgrade` reads.
- **`--analytics amplitude`** — wires the analytics seam to Amplitude
  with an API-key-guarded provider swap; stackable with `--backend` and
  `--error-reporting`.

## 0.12.0

- Template: **analytics seam** — an `AnalyticsService` interface with a
  debug-logging default, automatic screen-view tracking for every
  navigation (bottom tabs included), and a sample domain event. Swap one
  provider to wire a real product-analytics SDK; `--analytics` addons
  are next on the roadmap.

## 0.11.0

- **`--error-reporting sentry`**: wires sentry_flutter into the
  template's error hooks with DSN-guarded initialization (empty
  `SENTRY_DSN` keeps Sentry disabled, so fresh apps run untouched).
  Stackable with `--backend`, e.g.
  `fluframe create my_app --backend supabase --error-reporting sentry`.

## 0.10.0

- Template: **Japanese localization** (full `app_ja.arb` + language
  picker entry) alongside English and Korean; `FluFrame アプリ` joins
  the rename tokens so generated apps stay unbranded in every locale.
- Template: sixth theme preset (**teal**).

## 0.9.0

- Template: **global error handling hooks** — `FlutterError.onError` and
  `platformDispatcher.onError` route every uncaught error through one
  documented file (`core/logging/error_handlers.dart`), the exact seam
  for wiring Sentry/Crashlytics later.

## 0.8.0

- Template: **offline fallback cache** for the posts sample — the last
  successful response is persisted and served automatically when the
  network fails, demonstrating the repository-decorator pattern with
  zero new dependencies.

## 0.7.1

- Actually ships the **theme color presets** announced in 0.7.0 — a
  release-ordering mistake published 0.7.0 from a commit that did not
  yet contain them. No other changes.

## 0.7.0

> ⚠️ Published without the preset feature described below — use 0.7.1.

- Template: **five selectable theme color presets** (persisted) join the
  existing light/dark mode — pick Indigo/Emerald/Crimson/Amber/Violet in
  Settings, survives restarts.

## 0.6.0

- **`fluframe doctor`**: one command to verify the machine can generate
  and run fluFrame apps — Flutter/Dart/git probes with actionable fixes
  and a template-bundle check.

## 0.5.0

- **`--backend firebase`**: generate an app with Firebase Auth wired into
  the auth seam. Ships a compile-safe `DefaultFirebaseOptions` stub that
  throws with clear guidance until you run `flutterfire configure` —
  honest about the one step that cannot be automated.

## 0.4.0

- **`--backend supabase`**: generate an app with Supabase Auth already
  wired into the auth seam — `SupabaseAuthRepository`, env-based
  configuration (`SUPABASE_URL` / `SUPABASE_PUBLISHABLE_KEY` via
  `--dart-define-from-file`), and setup notes. The generated app's test
  suite stays green and offline regardless of backend.
- Backend addon mechanism (ADR 0001): dependencies via `flutter pub add`,
  bundled addon files, and anchored patches that fail loudly if the
  template and addon ever drift apart.

## 0.3.0

- **Backend-neutral auth scaffold** in the generated app (zero new
  dependencies): email/password login screen with validation, auth-gated
  profile tab, GoRouter redirect with return-path, and a session that
  survives restarts — all behind a single `AuthRepository` seam.
- Swap-in guides for **Supabase** and **Firebase** auth (one provider
  override) in the repository's `docs/guides/`.

## 0.2.0

- `--org` is now validated before anything runs: malformed identifiers
  (spaces, digit-leading or empty segments) produce a clear usage error
  instead of a downstream `flutter create` failure.
- A missing Flutter SDK now prints a friendly message with the install
  guide and exits 69, instead of dying with a raw `ProcessException` —
  on both the direct-spawn and Windows shell paths.

## 0.1.0

- Initial release.
- `fluframe create <name>` scaffolds a production-ready Flutter app:
  - Riverpod 3 (manual notifiers), go_router `StatefulShellRoute` tabs
  - freezed 3 + json_serializable models, dio with typed error mapping
  - Localization (en/ko) via `flutter gen-l10n`, Material 3 light/dark themes
  - Persisted settings (`SharedPreferencesAsync` behind a `KeyValueStore`)
  - `--dart-define-from-file` flavors, very_good_analysis, unit + widget tests
- Options: `--org`, `--description`, `--output-directory`, `--platforms`,
  `--no-pub`.
