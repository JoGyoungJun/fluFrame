# Changelog

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
