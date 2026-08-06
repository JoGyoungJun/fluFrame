# Changelog

## 1.2.0

**Correctness release.** A full audit of 1.1.0 found that the two things
fluframe promises — generate an app, then keep it up to date — could both
fail while reporting success. `upgrade --apply` destroyed every non-ASCII
character in a Korean or Japanese app and printed `conflicts: 0`; a
generated Firebase app opened to a black screen; `doctor` said "All set"
a minute before `create` died. Nothing below is a new feature.

Everything here is backwards compatible. Two behaviours changed on
purpose: `upgrade --apply` now requires a clean git working tree
(`--force` opts out), and it exits non-zero when conflicts remain.

- **Fixed: unexpected failures printed a raw stack trace and exited -1.**
  Only `UsageException` was handled, so a corrupt `.fluframe.json` or an
  unpublished `--from` version dumped a trace with no advice. Each now
  gets a sentence and a real exit code; genuine bugs still print the
  trace, after the message.
- **Fixed: a malicious bundle could write outside the extraction
  directory.** `templates/../../../probe.txt` passed the
  `startsWith('templates/')` check. Entries are now resolved against the
  destination and rejected by name, and every failure path cleans up its
  temp directory.
- **Fixed: `upgrade --apply` rewrote every line ending on Windows.** Line
  endings are normalized for comparison only; each file keeps the style
  it had. One non-UTF-8 file no longer aborts the whole run either — it is
  reported and skipped.
- **Fixed: `upgrade` ran happily in a directory that was not an app.**
  In an unrelated empty folder it reported "unchanged: 65 / added: 3" and
  exited 0. It now refuses without a `.fluframe.json` or a `pubspec.yaml`,
  and the `unchanged` count means what it says.
- Template: **boot survives a storage failure.** Four reads ran before
  `runApp` with no error handling, so one failure meant no widget tree at
  all. They fall back to defaults and report through the error seam.
- Template: **`AsyncValueWidget` can show a refresh over existing
  content.** Retry looked dead (so users tapped again, firing duplicate
  requests) and a failed pull-to-refresh discarded the list being read.
- Template: **the login button awaits its own work** and no longer loses
  non-`AuthException` failures; **`authController` stops resurrecting a
  signed-out session** when it is invalidated.
- Template: **`ApiException` carries the backend's response body**, so a
  generated app can read the server's own error code; `cancel` and
  `badCertificate` are no longer both "unknown".
- **Generated apps now ship their own CI workflow and an `AGENTS.md`**
  describing the app's conventions to a coding agent. Both are rewritten
  to the project's name.
- **Added: an example-drift gate.** `examples/` had lost
  `core/logging/error_handlers.dart` — the template's crash-reporting seam
  — while the docs claimed CI meant they "cannot rot". Both are re-synced
  (and gained the Japanese locale they were missing), and
  `tool/check_example_drift.dart` now fails CI on new drift.
- Coverage is measured for the CLI as well as the template, published to
  the job summary, uploaded as an artifact, and gated by a floor for the
  CLI. Addon sources are format-checked, since they ship into user apps.
- Docs: ADR 0003 (Riverpod without provider codegen) and ADR 0004
  (committed code generation) record two decisions the whole product
  rests on; `docs/architecture.md` no longer claims three rename tokens
  or an en+ko-only template.

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
- **Fixed: a failed `create` left you unable to retry.** Every failure path
  now prints where the half-written project is and the exact command to
  remove it — previously the obvious retry hit `Directory "./my_app"
  already exists. Aborting.` with no hint. `.fluframe.json` is written
  last, so a partial directory never looks upgradable.
- **Fixed: `doctor` said "All set" and then `create` failed.** It now
  checks that this machine can create symbolic links, which Flutter needs
  for the `windows` and `linux` plugins in the default platform set. On
  Windows the fix is Developer Mode; the message says so, and says how to
  scope the app instead. `create` repeats the hint if `pub get` still
  fails that way. The README quick start now starts with `fluframe doctor`.
- **Fixed: project names that could not work were accepted.** `dio`,
  `intl`, `go_router`, `shared_preferences`, `firebase_core` and the rest
  of the generated app's own dependencies were let through, then failed
  with `A package may not list itself as a dependency` — after generation
  had written the whole project. Windows device names (`con`, `aux`,
  `nul`, `com1`…`lpt9`) and leading underscores are refused too, and the
  rejection message now names the actual reason. A test fails if the
  dependency list drifts from `template/pubspec.yaml` or the addons.
- **Fixed: an incomplete template bundle produced a "successful" empty
  app.** The overlay deletes the scaffold's `lib/` before copying, so a
  bundle missing `lib`, `test` or `pubspec.yaml` yielded a project with no
  source — reported as a warning, exit 0. It is now a hard failure with a
  reinstall pointer.
- e2e now covers the shipped default platform set (all six), which no test
  had ever generated, and runs on Windows and macOS.
- **Fixed: generated apps still showed fluFrame's name.** The home screen
  greeted users with "Welcome to fluFrame!" in every locale and the root
  widget was called `FluFrameApp`, because the rewriter only replaces four
  exact tokens and none of those spellings is one. The greeting now uses
  the `FluFrame App` / `FluFrame 앱` / `FluFrame アプリ` tokens, the widget
  is `AppRoot`, and a test walks the real template sources so this cannot
  come back.
- **Fixed: `upgrade --apply` resurrected files you deleted.** A missing
  local file was treated as new, so deleted files came back — and a
  renamed one came back beside its copy, declaring the same class twice.
  They are now reported as `deleted locally - not restored`;
  `--restore-deleted` opts in.
- Template: **uncaught async errors no longer vanish in release builds.**
  `onPlatformError` returned `true`, suppressing Flutter's default log
  path, while the app's only sink was `dart:developer` — a VM service
  channel that does not exist in release.
- Template: **an unmatched deep link is no longer a dead end.** There was
  no `errorBuilder`, so go_router's default error page took over, and its
  only button navigates to `/` — a route the app did not define. There is
  now a localized not-found screen and a `/` → `/home` redirect.
- Template: **the offline cache no longer hides server errors.** It caught
  every `ApiException`, so a 404 or a 500 was answered with a stale copy
  and `PostDetailScreen`'s 404 branch could never run. Only
  `NetworkException` falls back now.
- **Fixed: `--backend firebase` opened to a black screen.**
  `Firebase.initializeApp` ran before `runApp` with a placeholder that
  throws until `flutterfire configure` — so the very first launch of every
  generated app died with no widget tree, no red error screen, and nothing
  in the log. It is now initialized after the error hooks, inside a
  try/catch, and the app runs on the in-memory auth fake until it is
  configured. `--backend supabase` behaves the same way with an empty
  `SUPABASE_URL`, matching how the Sentry and Amplitude addons already
  stayed inert without their keys.
- **Fixed: `--error-reporting sentry` lost most of what Sentry does.**
  `SentryFlutter.init` was called without `appRunner`, so zone errors were
  never captured — and the template then overwrote both handlers the SDK
  had just installed. The app now runs inside `appRunner:`, the SDK's
  integrations chain onto the template's handlers, and the hand-rolled
  `Sentry.captureException` calls are gone (they double-reported and
  marked everything `handled: true`).
- **Fixed: addon dependencies were installed unpinned.** `pub add` with no
  constraint resolves to whatever is latest, while the injected sources
  target one major — so an upstream major release would break newly
  generated apps on its release day. All four addons now pin
  `^major.minor`, and a test fails if any addon declares a dependency
  without a constraint. The constraint is written into `pubspec.yaml`
  rather than passed on the command line: `flutter` is a batch file on
  Windows, and `cmd.exe` eats the `^`.
- **Fixed: `--no-pub` still resolved dependencies.** It skipped
  `pub get` but ran one `pub add` per addon anyway. It now installs
  nothing and prints the `flutter pub add` line to run by hand.
- **Fixed: setup notes sent secrets into a committed file.** All three
  addons told users to put keys in `env/dev.json`, which the template's
  own `.gitignore` documents as committed safe defaults — secrets belong
  in `env/*.local.json`. The notes and the committed placeholders now
  agree.
- **Fixed: an addon could make an app permanently un-upgradable.**
  `upgrade` rebuilt the merge base by replaying the *current* CLI's addon
  anchors against an *archived* bundle, so moving any anchored template
  line blocked the upgrade at exit 70 for every app generated with an
  addon. Bundles now ship their own `templates/addons.json`, and when the
  addons cannot be replayed at all both sides are rebuilt without them
  and the report says so.
- Fixed: the injected `firebase_options` import landed at an unsorted
  position (its anchor named an import that stopped being last), as did
  the Sentry SDK import. `dart fix --apply` hid both — except under
  `--no-pub` and on the upgrade path.
- Template: screen-view analytics report the route **pattern**
  (`/home/posts/:id`), not the resolved path — concrete paths explode
  dashboard cardinality and would ship path secrets to a third party. The
  router also `read`s the analytics provider instead of watching it, which
  would have rebuilt the router and lost the navigation stack.

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
