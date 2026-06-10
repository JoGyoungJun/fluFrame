# Flutter App Framework

Status: Approved
Author: Codex
Last updated: 2026-06-10
Layer: core
Priority: MVP

## Summary

`fulFrame` is an open-source Flutter app framework for building production-ready
apps from a maintained, opinionated foundation. It should give developers a
clean architecture, reusable app shell, routing, theming, localization,
configuration, testing, and release scaffolding without forcing a single backend
or product domain.

The core problem is repetition. Most Flutter apps need the same baseline
capabilities: app bootstrap, environment configuration, routing, theming,
localization, error handling, logging, testing, CI, feature folder structure, and
release hygiene. Rebuilding those pieces for every new app wastes time and
causes inconsistent quality. FulFrame exists to prebuild those common pieces in
a reusable, open-source framework so each app can spend more effort on product
logic instead of infrastructure.

## Developer Fantasy

A developer should be able to start a serious Flutter app without spending the
first week debating folder structure, state boundaries, test setup, CI, and
boilerplate. The framework should feel boring in the best way: predictable,
documented, extensible, and easy to delete or replace piece by piece.

## Product Positioning

FulFrame is not a visual UI kit only, and not a low-code generator. It is a
framework starter plus package set that encodes practical Flutter application
architecture and open-source maintenance defaults.

FulFrame should be useful as both:

- a GitHub template for starting new apps quickly; and
- a set of packages that apps can adopt gradually.

## OSS Program Fit

FulFrame is intended as a public, actively maintained open-source project. The
project is a fit for OSS support because it targets a broad, recurring problem
in the Flutter ecosystem: every app team repeatedly implements similar
infrastructure before shipping product-specific features.

The project can use Codex in real maintainer workflows:

- review pull requests against architecture boundaries;
- triage issues into framework bugs, template gaps, documentation gaps, and
  feature requests;
- maintain release notes and migration guides;
- audit common app infrastructure for security and quality problems;
- keep examples, tests, and docs synchronized with framework changes;
- generate and validate starter app variations for common app types.

API credits would be used for repository maintenance automation, contributor
support, test and documentation workflows, and code quality review tooling. The
goal is not to replace maintainer judgment, but to reduce repetitive maintenance
work so the project can stay active and useful.

### Target Users

- Solo app developers who want a production baseline.
- Small teams starting apps with shared architecture.
- Open-source maintainers who need a clean example app and package structure.
- Flutter learners who have outgrown demo apps and need real project shape.
- Developers who build multiple apps and do not want to rewrite the same
  app-foundation features each time.

### Non-Goals

- Do not become a backend-as-a-service.
- Do not require Firebase, Supabase, or any single backend.
- Do not hide Flutter behind a new DSL.
- Do not ship a large visual design system in MVP.
- Do not support every state-management package in MVP.

## Source Notes

- Flutter's architecture guide recommends separating applications into UI and
  data layers, with views, view models, repositories, and services.
- The same guide describes repositories as the source of truth for model data.
- Flutter's package docs cover both using and developing packages/plugins.
- Flutter's testing overview separates unit, widget, and integration tests.
- Flutter's CI/CD docs list GitHub Actions and other CI options and discuss
  fastlane for release workflows.

Sources:

- https://docs.flutter.dev/app-architecture/guide
- https://docs.flutter.dev/packages-and-plugins
- https://docs.flutter.dev/testing/overview
- https://docs.flutter.dev/deployment/cd

## Core Rules

1. The framework is Flutter-first and Dart-first.
2. The default architecture uses feature-oriented modules with explicit layers:
   `ui`, `application`, `domain`, `data`, and `platform`.
3. The framework exposes replaceable contracts before concrete integrations.
4. The template app must run without external services.
5. Generated or scaffolded code must be readable and manually maintainable.
6. Every framework package must include an example, tests, and API docs.
7. The MVP must optimize for clarity over abstraction count.
8. Common app-foundation features should be implemented once in the framework
   and reused across apps.

## Proposed Package Shape

```text
packages/
  fulframe_core/
  fulframe_app/
  fulframe_testing/
  fulframe_lints/
examples/
  starter_app/
docs/
tool/
```

### `fulframe_core`

Foundational Dart contracts:

- `Result<TFailure, TValue>`
- `UseCase`
- `AppException`
- `Clock`
- `Logger`
- `Config`
- lightweight dependency registration contracts

### `fulframe_app`

Flutter-facing app shell:

- application bootstrap
- route shell conventions
- theme tokens
- localization loading conventions
- environment/flavor configuration
- error boundary widgets
- common screen/application lifecycle hooks
- common loading, empty, error, and retry UI patterns

### `fulframe_features`

Reusable app-foundation feature modules, added after the core package shape is
stable:

- authentication shell contracts, not provider-specific auth in MVP
- settings/preferences foundation
- offline/cache conventions
- notifications integration contracts
- onboarding flow foundation
- analytics event contracts

### `fulframe_testing`

Testing helpers:

- fake clocks
- fake loggers
- repository fakes
- widget harness helpers
- golden-test-ready wrappers, if adopted later

### `fulframe_lints`

Strict but practical lint rules:

- Dart analyzer configuration
- import boundary guidance
- formatting and quality defaults

## Architecture Model

| Layer | Owns | Must Not Own |
|-------|------|--------------|
| `ui` | widgets, screens, UI state display | network calls, persistence |
| `application` | view models, commands, orchestration | raw platform APIs |
| `domain` | entities, value objects, use cases | Flutter widgets |
| `data` | repositories, DTO mapping, cache policy | UI state |
| `platform` | plugins, OS-specific adapters | product rules |

## Extension Points

| Extension | MVP Default | Replacement Rule |
|-----------|-------------|------------------|
| Routing | Framework route contract with example implementation | Apps can swap the router adapter. |
| State | View model contract, no global mandatory package | Apps can use their preferred state package. |
| Backend | None | Integrations live in optional packages or app code. |
| Logging | Simple logger contract | Replace with Sentry, analytics, or custom logger. |
| Config | Environment file and compile-time defines | Replace with remote config later. |

## MVP Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FF-MVP-001 | Provide a compilable Flutter starter app. | High |
| FF-MVP-002 | Provide package structure for core/app/testing/lints. | High |
| FF-MVP-003 | Define architecture contracts and folder conventions. | High |
| FF-MVP-004 | Include unit, widget, and smoke-test examples. | High |
| FF-MVP-005 | Include CI for analyze, format, and tests. | High |
| FF-MVP-006 | Include open-source README, license, contributing guide, and code of conduct. | Medium |
| FF-MVP-007 | Include documentation for creating a new feature module. | Medium |
| FF-MVP-008 | Document the common app-foundation features FulFrame will prebuild. | High |
| FF-MVP-009 | Include an OSS application narrative for Codex for OSS submission. | High |

## Acceptance Criteria

- [ ] A new developer can clone the repository and run the example app.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] The example app demonstrates at least one feature using UI, application,
      domain, and data boundaries.
- [ ] The README explains who the framework is for and how to start.
- [ ] The README explains that FulFrame prevents rebuilding common app
      foundation features for every Flutter app.
- [ ] Each MVP package has a clear public API and avoids leaking implementation
      details across layers.
- [ ] The repository includes open-source contribution basics.
- [ ] `docs/oss-application.md` contains concise support-program application
      copy and API credit usage plan.

## Open Questions

| Question | Owner | Needed By | Resolution |
|----------|-------|-----------|------------|
| Should MVP use Riverpod, Provider, Bloc, or no mandatory state package? | User | Before architecture implementation | No mandatory package for MVP; use simple view model contracts first. |
| Should this publish packages to pub.dev immediately or start as a GitHub template first? | User | Before release epic | Start as a GitHub template first; revisit pub.dev after public alpha. |
| Which license should be used: MIT, BSD-3-Clause, or Apache-2.0? | User | Before repository publishing | MIT selected. |
| Should the default example app target mobile only, or mobile + web + desktop? | User | Before scaffold implementation | Web-first verification with mobile-compatible Flutter code; no Android or native desktop build requirement before public alpha. |
