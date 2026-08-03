# Changelog

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
