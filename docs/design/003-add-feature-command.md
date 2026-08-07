# 003 — `fluframe add feature <name>`

**Status**: APPROVED · **Issue**: [#100][issue] · **Size**: Feature

## Problem

`fluframe` is a one-shot CLI: you run `create` once and never again
(`upgrade` aside). The feature-first layout the template is built on is
documented in prose, so the second feature is hand-copied from
`features/posts/` — and the copy forgets the route registration, or the
Japanese ARB, or lands imports in an order `directives_ordering` rejects.

## Goals

- Scaffold a feature module into an existing fluFrame app, wired up:
  routes registered, strings in all three ARBs, tests that pass.
- Fail loudly and completely rather than half-editing an app.

## Non-goals

- Scaffolding anything but a feature module (`add screen`, `add model`).
- Teaching `upgrade` about user-added features.
- Interactive prompts.
- Running `flutter pub get` or `build_runner` for the user (see
  "No code generation" below).

## Design

### Surface

```
fluframe add feature <name> [--tab] [--dry-run] [--project-dir <dir>]
```

`--tab` also registers the feature as a bottom-navigation branch.
`--dry-run` prints the plan and writes nothing.

> `add` is **not** dry-run by default, unlike `upgrade`. `upgrade` rewrites
> files you already own and cannot be undone without git; `add` only
> creates new files and makes three bounded insertions. The asymmetry is
> stated in `--help` so nobody has to discover it.

### Generated files

```
lib/features/<name>/data/<name>_repository.dart      repository + provider
lib/features/<name>/presentation/<name>_controller.dart   AsyncNotifier
lib/features/<name>/presentation/<name>_screen.dart       screen
test/features/<name>/<name>_controller_test.dart
test/features/<name>/<name>_screen_test.dart
```

Every `package:` import uses the **app's own** package name, read from its
`pubspec.yaml` — not `fluframe_app`.

#### No code generation

The scaffold deliberately contains no `freezed` model. A generated
`@freezed` class does not compile until `build_runner` has run, so the
command would have to either shell out to a 30-second build or hand the
user an app that does not analyze — and the acceptance criteria require
`flutter analyze` and `flutter test` to pass immediately after.

The repository therefore returns `List<String>`. The screen's doc comment
points at `features/posts` for the freezed + `json_serializable` pattern
to copy when the feature grows a real model. This is a scaffold, not a
finished feature.

### In-place edits

Three insertions, all at explicit anchors added to the template by this
change:

| Anchor in `lib/app/router/app_router.dart` | Inserted |
|---|---|
| `// fluframe:routes` | a `GoRoute` at `/<name>` above the shell (no `--tab`) |
| `// fluframe:branches` | a `StatefulShellBranch` for `/<name>` (`--tab`) |
| `// fluframe:destinations` | a `NavigationDestination` (`--tab`) |

Plus the feature's screen import, inserted into the existing sorted
import block **at its sorted position** — not at a marker. The template's
`directives_ordering` lint is fatal, and re-sorting one block is
deterministic, whereas running `dart fix --apply` over the whole project
would silently rewrite the user's own code as a side effect.

An app generated before these anchors existed does not have them. The
command says so in one sentence and points at `fluframe upgrade`, which
is exactly the tool for that — it does not guess where the routes list is.

### Failure and atomicity

Every refusal exits non-zero with a single sentence:

| Condition | Message |
|---|---|
| No `.fluframe.json` and no `pubspec.yaml` | not a fluFrame app |
| `<name>` invalid | reuses `packageNameRejection`, which explains *why* |
| `lib/features/<name>/` exists | refuses rather than merging into it |
| An anchor is missing | run `fluframe upgrade` first |
| An ARB is missing or malformed | names the file |

**Every check runs before the first byte is written.** Nothing is
partially applied: the file set is computed, the three edits are computed
against in-memory copies, and only then is anything flushed. If a write
fails midway the already-written feature directory is removed and the
router is restored from the copy held in memory.

### Untranslated strings

`<name>Title` (and `<name>Tab` with `--tab`) are appended to all three
ARBs. The non-English files receive the **English** value, and the command
prints exactly which keys in which files still need translating — a silent
English string in `app_ja.arb` is how a template ends up shipping
half-localized.

The user runs `flutter gen-l10n` afterwards; the command says so rather
than doing it, because it does not otherwise touch the build.

## l10n keys

The command adds keys to the *user's* app, not to the template. The
template itself gains no new strings from this change.

## Test plan

`test/add_feature_test.dart` (unit, offline, against a fixture app):

1. Creates the five files, using the app's package name in imports.
2. `--tab` registers a branch and a destination; without it, a root route.
3. All three ARBs receive the keys; the output names the untranslated ones.
4. Refuses: not an app / invalid name / existing directory / missing
   anchor — each with a non-zero exit and a message naming the cause.
5. `--dry-run` prints the file list and the edits and writes **nothing**
   (asserted by comparing a directory listing and the router's bytes).
6. A failed write leaves no feature directory and an unmodified router.
7. The screen import lands in sorted position.

`test/create_e2e_test.dart` gains a variant: generate an app, run
`add feature --tab`, then `flutter analyze` and `flutter test` inside it.

## Acceptance criteria

Tracked on [#100][issue].

## Open questions

None.

[issue]: https://github.com/JoGyoungJun/fluFrame/issues/100
