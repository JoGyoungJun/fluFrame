# Changelog

## 1.6.0

**Everything a downloaded bundle could do to you, and four crashes that
reported themselves as fluframe bugs.** A full improvement pass over the
CLI and the template: 33 findings, the 13 highest-value fixed here. No CLI
flag changed meaning — but `upgrade` now refuses two things it used to
accept and one `add feature` failure exits on a different code, which is
why this is a minor and not a patch.

### The bundle `upgrade` downloads is now verified

- **The download is checked against pub.dev's own digest.** pub.dev
  publishes `archive_sha256` beside the archive URL; fluframe read past it
  and relied on the gzip CRC32, which anyone who rewrites the bytes
  recomputes for free. That archive is merged into your source tree, so it
  is now refused unless its SHA-256 is the one pub.dev published.
- **A hop off https is refused, not followed.** The archive URL, and any
  redirect away from it, must be https — or the plain-http registry you
  named yourself, which is what a self-hosted mirror and the tests use.
- **A bundle can no longer write outside your project.** Addon patch
  targets come out of the downloaded bundle's own `addons.json` and were
  joined onto your project root unvalidated, so a traversal path could
  rewrite an existing file anywhere you can write. Refused when the
  registry is parsed, and again before the file is touched.
- **An oversized archive stops before it is inflated**, instead of being
  decompressed into memory first and measured afterwards.

Adds `crypto` as a runtime dependency: Dart has no SHA-256 in core.

### `upgrade` no longer leaves an app it cannot finish

- **A failed write is a sentence, and not a half-upgrade.** One unwritable
  file — a lock, a read-only file, a full disk — used to escape mid-loop
  as "This is a bug", leaving some files upgraded, the recorded version
  untouched, and nothing anywhere to say so. The re-run then merged the
  same base against already-upgraded content and conflicted on files you
  never edited. Writes are now ordered so conflict markers land last, and
  a failure records no upgrade at all, which keeps the re-run a plain
  re-merge of exactly the files that never landed.
- **The scratch tree is deleted.** Every run, dry runs included, left two
  fully reconstructed app trees behind in your temp directory.
- **A hand-broken `.fluframe.json` dies as a sentence.** `backend`,
  `errorReporting` and `analytics` were still read with bare casts, so a
  wrong type in any of them printed "This is a bug" with a stack trace —
  the exact class the validation around them exists to prevent.

### Crashes that reported themselves as fluframe bugs

- **`add feature` prints its own recovery instructions.** When a rollback
  cannot put every file back, the scaffold names those files and tells you
  to restore them before building. That message was being buried under a
  crash trace, at precisely the moment you needed to read it. The exit
  code moved with it: that path now exits **74** (`EX_IOERR`) instead of
  the runner's catch-all **70**, so a script can tell a half-applied
  scaffold apart from a bug in fluframe.
- **An ARB that is not a JSON object** is now named as such, instead of
  raising a `TypeError` the CLI reports as a bug in itself.

### Generated apps

- **The load-more spinner can no longer hang forever.** A wrong-shaped
  page-two response raises a `TypeError`, which the controller's
  `on Exception` never caught: the loading flag stayed set, and the guard
  at the top of the method turned every later attempt into a no-op — a
  spinner with no error and no retry. Both the paging and the refresh path
  now surface it, so the retry the list footer already had appears.

### Repo

- Restored `docs/adr/` and `docs/design/`, which ten shipped source files,
  `docs/comparison.md` and this changelog already pointed at.
- The Gradle cache key for the generated-app Android build hashed files
  that build never uses, so it could never change: written once, then an
  exact hit forever, quietly reintroducing the download it was added to
  avoid.
- Every one of the 20 secret-scan patterns that gates `dart pub publish`
  now has a fixture, so a pattern that stops matching fails the suite
  instead of shipping a key.
- The settings fallbacks are pinned: theme preset, theme mode and locale
  are persisted by name, so renaming a value breaks stored settings.

## 1.5.0

**Two features, and the audit of everything around them.** Two repo-wide
audits ran between 1.4.1 and this release; every defect they proved landed
here. Backwards compatible — no CLI flag changed meaning.

### New

- **Generated apps handle a desktop window.** Body content is capped at
  840dp — the Material 3 expanded-window floor — via a shared
  `ContentWidth` widget. Scrollables are capped by padding, not wrapping,
  so the mouse wheel keeps working across the whole window. Phone layout
  is untouched, down to widget offsets. `add feature` emits the cap for
  you (and skips it in apps generated before it existed, which would not
  compile otherwise).
- **CI compiles what generation produces.** This repo now builds a real
  generated app for Android on every push and for iOS and Linux nightly —
  previously nothing ever ran Gradle, so the template's AGP/Kotlin/Gradle
  pins shipped untested.

### The upgrade path, made honest

- **The merge base now matches your app.** `create` ends with
  `dart fix --apply`, which re-sorts imports after the package rename; the
  upgrader's reconstructed base skipped that, so for most project names
  dozens of untouched files were reported as "your edits kept" — 25 files
  for a plain `my_app`, more with a backend addon, whose spliced imports
  and missing pubspec entries diverged the same way. The overlay now
  sorts imports and writes addon dependencies into pubspec.yaml itself,
  on every path, so the base is byte-identical to what `create` produced.
- **Resolving a conflict no longer loops.** Keeping any of your own code
  used to make the re-run re-merge the same base and write markers back
  into the file you just fixed. A conflicted `--apply` now records the
  upgrade in progress in `.fluframe.json`; the re-run finishes it.
  Works for `--from` apps too, which previously dead-ended on
  "No .fluframe.json found" — about the file fluframe had just written.
- **An older CLI refuses to downgrade a newer app** instead of silently
  reverting template files and rewriting the recorded version — exit 0,
  content gone — which is what it did.
- **`--from` reads the package name from pubspec.yaml**, not the folder
  name. A checkout directory like `checkout-2024` used to end up in
  imports as a package that does not exist (and, with a hyphen, could
  not).

### `fluframe add feature`

- Multi-word names produce lowerCamelCase identifiers
  (`orderHistoryControllerProvider`), not snake_case ones the analyzer
  rejects — `flutter analyze` was failing on code the scaffold itself
  wrote.
- Scaffolded files' imports are emitted sorted for YOUR package name.
  The hardcoded order was only right for names sorting before `flutter`,
  which most real names do not.
- A locale you added (a fourth ARB) gets the new keys too, instead of
  being silently skipped while the app's own parity test goes red.
- A CRLF working tree stays CRLF: inserting a route no longer rewrites
  every line of the router and all ARBs to LF.
- The dry run prints the key names that will actually be written.

### Sharper failures

- On Korean/Japanese Windows consoles, a missing Flutter is reported as a
  missing Flutter — not as "Malformed JSON ... .fluframe.json", which is
  what a cp949 shell message crashing the strict UTF-8 decoder produced.
- Hand-edited `.fluframe.json` with wrong-typed values gets one sentence
  naming the key, instead of a TypeError labelled "This is a bug".
- A `cliVersion` that is not a version ("abc") is named before any
  network I/O, instead of pub.dev's 400 being relayed as "usually
  temporary — try again in a minute".
- The cleanup command printed after a failed create quotes its path;
  unquoted, `rmdir /s /q C:\temp\my folder\app` deletes `C:\temp\my`.
- `--no-pub` with a backend addon now yields an app whose pubspec already
  carries the pinned dependencies (carets intact — the old
  `flutter pub add "pkg:^x"` next-step lost the caret on every shell but
  cmd.exe) and which passes `flutter analyze` as generated.

### Template

- The CI workflow shipped into generated apps declares
  `permissions: contents: read` instead of inheriting the org default,
  which in legacy-settings organizations is read-write.
- `PostDetailScreen`/`PostNotFoundScreen` and the 404 branch are tested;
  no widget test can reach the network; a corrupt offline-cache blob is
  discarded instead of crashing the offline path (reaches existing apps
  via `fluframe upgrade`).

## 1.4.1

**Six defects, five of them in code that only runs when something has
already gone wrong.** No CLI surface changed; nothing here needs anything
from you but the upgrade.

- **Fixed: `fluframe upgrade` could hang forever.** The bundle download
  created a bare `HttpClient` with no connect timeout and no deadline on
  any request, so a connection that is *accepted* and then goes nowhere —
  a captive portal, a proxy blackhole — left `Fetching the fluframe X
  template bundle…` on screen with no way to tell a hang from a slow link.
  It now gives up after 10s connecting, 30s on the version document and
  60s on the archive, and says which URL and which limit. No retries: a
  second attempt down the same hole doubles the wait.

- **Fixed: a half-downloaded bundle became a merge base.** The `archive`
  package's gzip decoder does not raise on a truncated stream — it inflates
  what it can and returns it. So a download that lost its tail turned into
  a *partial* template, and `upgrade` then reported a conflict on a file you
  never edited, and offered to `--apply` it. The archive's own CRC32 and
  length trailer are now checked, which catches a stream cut one byte short
  that a `Content-Length` check would pass.

- **Fixed: `fluframe add feature` left your app non-compiling if a write
  failed.** It wrote the feature files, then `app_router.dart`, then the
  three ARBs — and rolled back by deleting only the feature directories. A
  failure on any ARB (read-only file, full disk; `app_ko.arb` goes last)
  left the router importing and routing to a class whose file had just been
  deleted, plus whichever ARBs had already taken the new keys — and the
  obvious next move, running it again, was refused with
  `app_en.arb already defines "…"`. The router and all three ARBs are now
  restored to their original bytes.

- **Fixed: a corrupt offline cache crashed the generated app.** The posts
  cache was decoded with no guard, from inside the handler that exists to
  serve you something when the network is gone. Malformed JSON surfaced as
  a parse error instead of "you are offline"; JSON of the wrong shape raised
  a `TypeError`, which is an `Error` rather than an `Exception`, so the
  controller never caught it at all. The blob now carries a schema version,
  every unreadable form is treated as "no cache", and a bad blob is deleted
  rather than re-parsed on every later read. **This one is in the template**,
  so it reaches an existing app through `fluframe upgrade`.

- **Fixed: the published bundle had no negative space.** `sync_template`
  copied every overlay entry verbatim, and `env/` is one of them — the
  directory `template/.gitignore` documents as where real secrets go. The
  package's own `.gitignore` hides the staged bundle from `git status`, so
  the local publish fallback could have uploaded a credential that appeared
  in no diff. The sync now filters against `template/.gitignore` itself, and
  the finished bundle is rescanned for secret-shaped files before upload.

- **Fixed: pub.dev scored 1.4.0 at 150/160.** `dart analyze` exits 0 on
  infos while pana scores them, so one `INFO` shipped and cost 10 points.
  CI now runs `--fatal-infos`.

Also: `PostDetailScreen` and `PostNotFoundScreen` — including the 404
branch with a documented regression history — now have tests in the
template your app is generated from.

## 1.4.0

**The bugs a first arrival would actually hit.** Nothing here is a new
feature; it is the pass you make before telling people the project exists.
Backwards compatible — no CLI surface changed.

- **Fixed: `fluframe add feature` wrote a broken description into your
  `app_en.arb`.** `'Label for the $entry.key screen.'` is `$identifier`
  interpolation, so every scaffolded feature landed
  `"description": "Label for the MapEntry(billingTitle: Billing).key screen."`
  in the `@`-metadata block — the contract with translators. Shipped since
  1.3.0. Regenerate the block by hand, or re-run `add feature` on a fresh
  key; the fix does not rewrite what earlier versions already wrote.

- **Fixed: `fluframe doctor` said "All set" without checking your SDK.**
  It printed `flutter --version` and compared it to nothing, so a machine on
  an older stable channel was told it was fine and only found out a minute
  into `create`, in a raw pub solver error. `doctor` now reads the floor out
  of the template's own `environment: sdk:` — one copy, so it cannot drift —
  and fails with the version it found, the version required, and
  `flutter upgrade`. A constraint it cannot bound is skipped rather than
  failed: a wrong floor rejects a machine that would have worked.

- **Fixed: the generated app never mentioned the CLI that generated it.**
  `README.md` and `AGENTS.md` taught only the manual way to add a feature,
  and nothing explained the `.fluframe.json` you were asked to commit. Both
  now lead with `fluframe add feature`, and the README documents
  `fluframe upgrade` properly: dry-run by default, `--apply` requires a
  clean git tree, conflicts come back as ordinary git markers, plus
  `--restore-deleted` and `--from`.

- **Fixed: the auth guides reproduced a boot failure the addons exist to
  prevent.** Both told you to initialize the SDK "right after
  `WidgetsFlutterBinding.ensureInitialized()`" — before the error hooks, so
  a throwing `initialize()` escaped into the root zone with no widget tree
  to show it. A black screen with the error nowhere. The guides now match
  what `--backend supabase` / `--backend firebase` actually generate,
  including the configured-or-fallback guard they were missing entirely and
  the dependency pins the CLI uses.

- **Fixed: the English language picker named Japanese in English.** It read
  `System · English · 한국어 · Japanese`; `app_en.arb` was the only ARB not
  using the endonym. Now `日本語`, with a test asserting the literal in all
  three locales — "all three agree" is also satisfied by all three
  regressing.

- **Fixed: both example apps showed fluFrame's name in Japanese.** Their
  `app_ja.arb` still carried the unrewritten `FluFrame アプリ` while en and
  ko were correctly renamed. Found by the new value check below.

- **Added: `check_example_drift --fix` repairs ARB keys.** It used to
  re-sync every file it owned and report success while the ARBs were still
  missing the keys the template had just gained — twice in the 1.3.0
  milestone alone. It now inserts missing keys with their `@`-metadata,
  preserves existing order, never removes a key the example owns, and
  compares shared values after the rename tokens. A differing value is
  reported and deliberately left alone, because overwriting a translation is
  worse than the drift.

- **Added: an ARB locale-parity test.** Nothing compared the three ARBs to
  each other. `gen-l10n` falls back to English for a missing key and only
  warns, so a locale could silently stop being translated with CI green. Six
  documents also said the template had two locales; all six now say three.

- **Security: every GitHub Action is pinned to a commit SHA.**
  `publish.yml` granted the OIDC scope that mints a pub.dev credential in
  the same job that ran a third-party action on a mutable `@v2` tag. Both
  workflows now default to `permissions: contents: read`. Adds `SECURITY.md`
  with a private disclosure channel, and Dependabot for actions and both
  pubspecs.

- **Docs: prerequisites and the `PATH` step that was missing everywhere.**
  No document stated a minimum Flutter version (3.44 / Dart 3.12), and all
  four entry points said `dart pub global activate fluframe` then
  `fluframe ...` with nothing about the pub cache not being on `PATH` — the
  first failure a newcomer can hit, and the one `doctor` cannot diagnose
  because `doctor` is the command that will not run. The pub.dev usage block
  also ran `upgrade` above `create`; it is now runnable top to bottom.

## 1.3.0

**`create` was the only command you ever ran twice — by starting over.**
This release adds the one you run every time the app grows a feature, and
makes the project something you can look at before installing anything.

Backwards compatible. `fluframe add feature` needs anchors that ship with
this version's template, so an app generated earlier needs
`fluframe upgrade` first — the command says so and changes nothing until
you do.

- **Added: `fluframe add feature <name> [--tab] [--dry-run]`.** Scaffolds
  a feature module into an existing app — repository, controller, screen
  and two tests — registers its route (or a bottom-navigation tab with
  `--tab`), and adds the strings to all three ARBs. It names the keys
  that still carry the English text rather than letting a silent English
  string sit in `app_ja.arb`.

  Nothing is written until the whole change has been computed: the name,
  the app, an existing feature directory, the router anchors and every
  ARB are checked first, and a failed write removes the feature directory
  it had already created. `--dry-run` prints the plan and writes nothing.
  Unlike `upgrade`, it is not dry-run by default — it only creates new
  files and makes bounded insertions — and `--help` says so.

  The scaffold deliberately contains no `freezed` model: a generated
  `@freezed` class does not compile until `build_runner` has run, and the
  app must analyze and test cleanly the moment the command exits. The
  screen points at `features/posts` for the real pattern.

- **Added: a live demo of a generated app** at
  <https://jogyoungjun.github.io/fluFrame/> — the template with zero
  edits, built for web and redeployed from `main` after every gate
  passes. Linked from all three READMEs.

- **Template: the posts list is now paginated** with infinite scroll, and
  is the reference implementation for the four things the first attempt
  gets wrong: appending instead of replacing, one request per frame near
  the bottom, no representation of "there is no more", and discarding the
  list when a later page fails.

  Riverpod's `ref.invalidate` reuses the notifier instance and leaves it
  mounted, so a page still in flight during a pull-to-refresh will
  silently append onto the freshly reloaded first one. A generation
  counter is what prevents that; `ref.mounted` does not.

  Consequence worth knowing: the offline fallback cache holds page one
  only, so an offline post-detail lookup now covers the first 20 posts
  rather than all of them.

- **Docs: `docs/comparison.md`** — fluFrame against `flutter create`,
  Very Good CLI and cloning a boilerplate, with every claim about the
  other tools taken from their current sources and the check date stated.
  It names five cases where you should pick something else.

- Corrected locale claims that went stale when Japanese was added: the
  READMEs said "4 locales" (there are three, plus a System option) and
  four places still described the template as English + Korean.

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
