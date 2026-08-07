---
name: new-feature
description: Add a new feature module to the template app following the fluFrame feature-first conventions — scaffolding, providers, routes, l10n (en+ja+ko), tests, and full verification.
argument-hint: "<feature-name> [description]"
---

Add a feature module to `template/` without breaking the boilerplate's
guarantees. Study `features/posts/` (async REST pattern) and
`features/settings/` (persisted state pattern) first and mirror whichever
fits.

## Conventions (non-negotiable)

- Layout: `lib/features/<name>/{data,domain,presentation}/` — repositories
  in data/, freezed models in domain/, controllers + screens in
  presentation/.
- State: manual Riverpod 3 notifiers (`Notifier`/`AsyncNotifier`), no
  provider codegen. Advanced types (`FutureProviderFamily`, `Override`)
  come from `package:flutter_riverpod/misc.dart`. Family args go to the
  notifier constructor.
- Every UI string goes into BOTH `lib/l10n/app_en.arb` AND `app_ko.arb`,
  then `flutter gen-l10n`. Never hardcode UI text. Use ICU plurals for
  counts.
- Async UI goes through `core/widgets/async_value_widget.dart` — pass
  `messageOf` for feature-specific error text and `onRetry`.
- Repositories throw typed `ApiException`s (map with `mapDioException`),
  never raw `DioException`.
- Routes register in `lib/app/router/app_router.dart`; validate path
  params (see the posts `:id` route — unparseable ids get a not-found
  screen, never a fabricated default).
- Keep rename tokens intact: `fluframe_app`, `FluFrame App`,
  `FluFrame 앱`. Use package imports (`package:fluframe_app/...`).
- Generated files (`*.freezed.dart`, `*.g.dart`, `lib/l10n/gen/`) are
  committed together with their sources.

## Tests (required before done)

- Controller/repository unit tests using `createContainer()` from
  `test/helpers/helpers.dart` (it disables Riverpod auto-retry) and
  `InMemoryKeyValueStore` / fake repositories via provider overrides.
- A widget test for each screen behavior worth keeping, using
  `tester.pumpApp(...)` — cover the error/retry path, not just the happy
  path.

## Finish

Run `/verify` (template analyze 0 issues + all tests green is the bar),
then propose a commit: `feat(template): <feature> ...` per the
Conventional Commits rule in CONTRIBUTING.md.
