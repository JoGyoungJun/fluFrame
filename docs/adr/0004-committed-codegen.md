# 0004 — Code generation for models and strings, output committed

> Historical record: written against fluframe 1.1.0; current behaviour is defined by the code and CHANGELOG.

- **Status**: Accepted
- **Date**: 2026-08-06
- **Related**: `template/l10n.yaml`, the *Verify generated code is up to
  date* job in `.github/workflows/ci.yml`; recorded retroactively while
  auditing 1.1.0

## Context

Two things in the template are mechanical enough to generate: immutable
data models (equality, `copyWith`, JSON) and localized strings. Both
also sit on the critical path of "does a freshly generated app compile
at all", which makes *when* the generator runs a bigger question than
whether to use one. A user who runs `fluframe create` and gets a red
squiggle on `_$Post` before they have ever heard of `build_runner` has
been failed by the boilerplate, not by their tooling.

This ADR is written late, and the audit finding that prompted it is
worth recording: the template is **already** paying the codegen cost —
freezed, json_serializable and build_runner are all in
`template/pubspec.yaml` — so "we skipped codegen to stay light" was not
an argument anyone could still make. The choice had been made; it just
had no record, which is how a later contributor talks themselves into
reversing half of it.

## Decision

We will generate, and we will commit the output.

- **Models**: `freezed` 3 + `json_serializable`, driven by
  `build_runner`. freezed 3 requires the `abstract class X with _$X`
  form (or `sealed`); consumers prefer Dart `switch` patterns over the
  legacy `when`/`map`.
- **Strings**: `flutter gen-l10n` from `lib/l10n/app_*.arb` into
  `lib/l10n/gen/` (`l10n.yaml`). Flutter 3.44 removed the synthetic
  `package:flutter_gen`, so the output is ordinary source in the app.
- **Every generated file is committed** — `*.freezed.dart`, `*.g.dart`,
  and `lib/l10n/gen/`. A clone of this repo, a downloaded example, and
  an app produced by `fluframe create` all compile with no generator
  step.

## Alternatives considered

- **Hand-written models** — no generator, no committed output, no CI
  check. Rejected on the arithmetic: `Post` is four fields, and by hand
  that is `==`, `hashCode`, `copyWith`, `toJson`, `fromJson` and a
  `toString` to maintain in lockstep, with a silent bug (a field left
  out of `==`) as the failure mode. This is precisely where generation
  earns its keep, unlike providers
  ([ADR 0003](0003-riverpod-manual-notifiers.md)).
- **dart_mappable** — solves the same problem with one annotation and
  fewer `part` files, and handles polymorphism more gracefully.
  Rejected on gravity rather than merit: freezed is what Flutter
  tutorials, Riverpod's own docs and most LLM-generated code assume, and
  a boilerplate's job is to look familiar. It still needs build_runner,
  so it would not remove the cost we are weighing.
- **built_value** — mature and very strict, but the builder-object API
  colours every call site and its ergonomics have aged; no reason to
  pick it over freezed today.
- **Running codegen inside the CLI at create time** (instead of
  committing) — tempting, and rejected as fragile. It puts a cold
  `build_runner` run inside `fluframe create`, on the user's machine,
  with their SDK, where a generator or resolution failure lands on
  someone who has not yet seen the app work. Committing inverts that:
  the generated code is already correct and the token rewriter carries
  it across the rename, so `FluFrame App` → the user's title lands in
  `lib/l10n/gen/app_localizations_en.dart` like any other text file.
  That is why `create` can treat its `flutter gen-l10n` call as
  best-effort — it warns and continues, and the app still builds with
  the right title.

## Consequences

- **Every source change needs a matching regen commit.** Enforced, not
  documented: the template CI job runs `build_runner build
  --delete-conflicting-outputs`, then `git add -A lib` and
  `git diff --cached --exit-code -- lib`. The staging step is
  deliberate — plain `git diff` is blind to a *new* generated file a
  contributor forgot to add.
- Diffs are noisier and merge conflicts in generated files are real.
  They are resolved by regenerating, never by hand-editing.
- **`build_runner` stays at `^2.15.1` and resolves to 2.15.1.** freezed
  3.2.x caps `analyzer` below the bound build_runner 2.15.2 requires, so
  the solver picks the older one on its own; raising the constraint past
  it does not upgrade anything, it makes the resolution unsolvable. The
  committed `template/pubspec.lock` records the working set
  (analyzer 10.2.0, freezed 3.2.5). Revisit when freezed widens its
  analyzer bound — a deliberate dependency-upgrade pass, not a casual
  bump.
- **The analyzer is told to skip the output**, via
  `analysis_options.yaml` excludes for `lib/l10n/gen/**`,
  `**/*.freezed.dart` and `**/*.g.dart`. Committing generated code
  otherwise means holding machine output to `very_good_analysis` with
  infos fatal — an unwinnable fight against the generator's author.
  `dart format --set-exit-if-changed lib test` still covers them, which
  is what catches a generator upgrade that reformats.
- **A new UI string is a three-file change plus a regen** —
  `app_en.arb`, `app_ko.arb`, `app_ja.arb`, then `flutter gen-l10n`.
  Note what CI does *not* do here: gen-l10n falls back to English for a
  missing translation and only warns, so the committed-output check
  proves the generated files match the ARBs, not that all three ARBs are
  complete. That last mile is review.
