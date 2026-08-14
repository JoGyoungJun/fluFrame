# 0003 — Riverpod 3 with hand-written notifiers, no provider codegen

> Historical record: written against fluframe 1.1.0; current behaviour is defined by the code and CHANGELOG.

- **Status**: Accepted
- **Date**: 2026-08-06
- **Related**: `template/lib/features/*/presentation/`; recorded
  retroactively while auditing 1.1.0

## Context

State management is the one choice a boilerplate cannot leave open: it
fixes the shape of every feature module, every test helper, and every
line of the "add a feature" guide, and changing it later means rewriting
all three plus every app already generated. Riverpod 3 itself offers two
ways to declare a provider — the `@riverpod` annotation with
`riverpod_generator`, which most of its documentation shows, and
hand-written `Notifier`/`AsyncNotifier` subclasses. The template's
promise is that a freshly generated app compiles and passes its tests
before the user has installed anything else, so anything standing
between a contributor and their first provider is a cost.

## Decision

We will use `flutter_riverpod` 3 with **hand-written** `Notifier` /
`AsyncNotifier` subclasses and plain top-level
`NotifierProvider` / `AsyncNotifierProvider` / `FutureProvider` finals.
`riverpod_generator` and `riverpod_annotation` are not dependencies of
the template, and `@riverpod` appears in no generated app.

The canonical shape is
`template/lib/features/posts/presentation/posts_controller.dart`: a class
extending `AsyncNotifier<T>` whose `build()` watches a repository
provider, paired with a top-level
`AsyncNotifierProvider<PostsController, T>` final. (`T` was `List<Post>`
when this ADR was written; design spec 004 later widened it to
`PostsState` for pagination — the shape is unchanged.)

## Alternatives considered

- **`riverpod_generator`** — the alternative with real merit, not a
  strawman: less boilerplate, provider names and family types derived
  from the signature, and no way for the `NotifierProvider<X, T>` type
  arguments to drift from the class. Rejected because it makes
  `build_runner` a prerequisite for *writing a provider*: a typo yields a
  generator stack trace instead of an analyzer error, and every new
  provider costs a rebuild. We do accept generated code for models
  ([ADR 0004](0004-committed-codegen.md)) — the leverage per line there
  is far higher.
- **bloc** — the other mainstream choice, with a stricter event/state
  discipline and a better-defined testing story (`bloc_test`). Rejected
  on ceremony: the same counter costs an event class, a state class and a
  `BlocProvider` placed in the widget tree, and test dependency injection
  is per-subtree rather than one container of overrides. A boilerplate
  multiplies per-feature ceremony by every feature its users write.
- **provider** — fewest concepts and no codegen at all, but it resolves
  dependencies through `BuildContext` and has no built-in
  loading/error/data value. The template leans hardest on exactly what
  that forbids: `initialXProvider` overrides computed *before* `runApp`
  (persisted theme, locale) and `AsyncValueWidget` over `AsyncValue`.
- **signals** — genuinely terse and codegen-free, and the closest thing
  to a free lunch here. Rejected on ecosystem risk rather than design: a
  generated app should still build in two years, and its Flutter binding
  is younger and far less depended-upon than Riverpod's. That is a bet a
  template has no right to make on its users' behalf.

## Consequences

- More boilerplate per provider — the class, the `final`, and the type
  arguments written twice. A mismatch is a compile error rather than a
  silent bug, so the cost is keystrokes, not correctness.
- Adding a provider needs no `build_runner` run. `fluframe add feature`
  and the guides can say "write this file"; the CI codegen check stays
  about models and ARB files only.
- **Family arguments go to the notifier's constructor, not `build()`.**
  Riverpod 3 moved them, and the compiler blames the provider rather
  than the `build(int id)` override that caused it.
- **Legacy providers are banned in new code.** `StateProvider`,
  `StateNotifierProvider` and friends still exist behind
  `package:flutter_riverpod/legacy.dart` — importable, working, and the
  first thing an old tutorial or an LLM reaches for. Nothing under
  `template/` or `examples/` imports that library, and it is a review
  rejection when it appears.
- **The v3 import split is load-bearing.** `Override`, `ProviderFamily`,
  `FutureProviderFamily` and the other reified types come from
  `package:flutter_riverpod/misc.dart`, while `hasError`/`valueOrNull`
  are extensions requiring `flutter_riverpod.dart` itself; files using
  both import both, in one sorted block (`directives_ordering`).
- Tests build containers with `ProviderContainer.test(...)` and pass
  `retry: (retryCount, error) => null`. Without it, v3's automatic retry
  quietly re-runs a provider a test deliberately failed.
