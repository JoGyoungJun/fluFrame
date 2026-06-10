# FulFrame MVP Plan

Last updated: 2026-06-10

## MVP Definition

FulFrame MVP is the smallest public open-source version that proves the core
idea: Flutter developers should not rebuild the same app foundation for every
new app.

The MVP must provide a working starter app, reusable core contracts, app shell
helpers, testing helpers, lint/CI defaults, and documentation that explains how
to build a feature using the framework.

## MVP Outcome

A developer can clone the repository, run the starter app, inspect one realistic
feature, and understand how FulFrame reduces repeated setup work across Flutter
apps.

## MVP User Promise

FulFrame gives you:

- a repeatable app architecture;
- a starter app that runs without backend setup;
- common contracts for result handling, use cases, config, logging, and time;
- an app shell for error handling and common UI states;
- testing helpers for deterministic app-foundation tests;
- lint, analyze, test, and CI defaults;
- documentation for adding a new feature module.

## MVP Package Scope

| Package | MVP Role | Required In MVP |
|---------|----------|-----------------|
| `fulframe_core` | Pure Dart foundation contracts. | Yes |
| `fulframe_app` | Flutter app shell and common UI foundation. | Yes |
| `fulframe_testing` | Fakes and widget/test harness helpers. | Yes |
| `fulframe_lints` | Shared quality defaults. | Yes |
| `fulframe_features` | Reusable app-foundation feature modules. | No, documented as post-MVP. |

## Required MVP Features

### 1. Workspace And Tooling

- Monorepo package layout.
- Melos bootstrap, analyze, test scripts.
- GitHub Actions quality workflow.
- Root README with problem statement and quick start.
- Flutter setup doc.

### 2. Core Contracts

- `Result<TFailure, TValue>`.
- `UseCase<TInput, TOutput>`.
- `NoInput`.
- `AppException`.
- `Clock` and `SystemClock`.
- `AppLogger` and `NoopLogger`.
- `AppConfig`.

### 3. App Shell

- `FulFrameAppShell`.
- Error boundary behavior.
- Loading, empty, error, retry state widgets.
- App lifecycle hook contract.
- Basic theme token structure.

### 4. Starter App

The starter app must include one realistic local-only feature. Recommended MVP
feature: **Task List**.

Task List is intentionally simple but exercises all core layers:

- `domain`: `TaskItem`, task validation rules.
- `application`: task list view model/use cases.
- `data`: in-memory task repository.
- `ui`: list, add action, empty state, error state.
- `testing`: fake repository or fake clock.

No backend is required.

### 5. Testing And Evidence

- Core unit tests.
- Starter app widget test.
- At least one application-layer test for the sample feature.
- CI runs analyze and tests.

### 6. Open-Source Readiness

- README.
- MIT license.
- `CONTRIBUTING.md`.
- `CODE_OF_CONDUCT.md`.
- Issue templates.
- PR template.
- Roadmap.
- Codex for OSS application notes.

## Explicit Non-Goals

- No Firebase/Supabase/backend integration in MVP.
- No authentication implementation in MVP.
- No published pub.dev release in MVP.
- No CLI generator in MVP.
- No large visual design system in MVP.
- No mandatory state-management package in MVP.
- No Android or Windows native build requirement before Public Alpha.

## MVP Milestones

### Milestone 0: Repository Foundation

Status: Mostly complete.

Definition of Done:

- [x] Flutter SDK installed.
- [x] Monorepo scaffold exists.
- [x] Bootstrap succeeds.
- [x] Analyze succeeds.
- [x] Tests succeed.
- [ ] First commit pushed to GitHub.

### Milestone 1: Core Contracts

Definition of Done:

- [ ] Core contracts are implemented.
- [ ] Core tests cover success and failure paths.
- [ ] Public API docs explain intended usage.
- [ ] Example app imports and uses `fulframe_core`.

### Milestone 2: App Shell And UI States

Definition of Done:

- [ ] `FulFrameAppShell` has documented responsibilities.
- [ ] Loading/empty/error/retry widgets exist.
- [ ] Starter app uses the shell and state widgets.
- [ ] Widget tests cover state rendering.

### Milestone 3: Starter Feature

Definition of Done:

- [ ] Starter app has a task-list feature.
- [ ] Feature follows `ui/application/domain/data` boundaries.
- [ ] Feature can be copied as a pattern for new modules.
- [ ] Feature docs explain each layer.

### Milestone 4: OSS Readiness

Definition of Done:

- [x] License chosen and added.
- [x] README explains purpose, quick start, packages, and MVP status.
- [x] Contribution docs exist.
- [x] Issue and PR templates exist.
- [x] Codex for OSS notes are ready for submission.

## MVP Acceptance Criteria

- [ ] `dart run melos bootstrap` passes.
- [ ] `dart run melos run analyze` passes.
- [ ] `dart run melos run test` passes.
- [ ] Starter app runs on Chrome or local Flutter target.
- [ ] README explains why repeated Flutter app-foundation work is the problem.
- [ ] A contributor can understand the architecture from docs and sample feature.
- [ ] The repository is public and has a first pushed commit.

## Recommended Defaults

These are MVP defaults unless the user overrides them:

- State management: no mandatory package; use simple view model contracts first.
- Publishing: GitHub template first, pub.dev after public alpha.
- Platform target: web-first verification plus mobile-compatible code.
- License: MIT.

## Next Implementation Story

Implement `production/epics/core/story-define-core-contracts.md`, then update the
starter app to use the contracts in a realistic local-only feature.
