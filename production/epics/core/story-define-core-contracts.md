# story-define-core-contracts

Status: Complete
Epic: `production/epics/core/EPIC-framework-core.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Logic
Priority: High

## Goal

Complete the MVP `fulframe_core` API surface so every later app-foundation
feature can depend on stable pure Dart contracts.

## Acceptance Criteria

- [x] Given an app feature needs success/failure modeling, when it imports
      `fulframe_core`, then `Result<TFailure, TValue>` supports explicit
      success and failure handling.
- [x] Given a feature has executable application logic, when it uses a use case,
      then `UseCase<TInput, TOutput>` provides a consistent async contract.
- [x] Given a feature needs deterministic tests, when it depends on time or
      logging, then it can use `Clock` and `AppLogger` contracts.
- [x] Given an app has environment-specific values, when it reads config, then
      it can use an `AppConfig` contract without depending on a backend.
- [x] Given the public package is analyzed and tested, when workspace checks run,
      then `dart run melos run analyze` and `dart run melos run test` pass.

## Implementation Notes

- Relevant files: `packages/fulframe_core/lib`, `packages/fulframe_core/test`.
- Existing scaffold already includes initial versions of these contracts.
- Keep `fulframe_core` pure Dart. Do not import Flutter.
- Non-goals: dependency injection container, code generation, backend adapters.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| Workspace analyze | `dart run melos run analyze` | Yes |
| Workspace tests | `dart run melos run test` | Yes |
| Core API files | `packages/fulframe_core/lib` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-09 | Expanded core MVP contracts and tests. | `packages/fulframe_core/lib`, `packages/fulframe_core/test` | Added Result helpers, config implementation, fixed clock, memory logger, and use-case tests. |
| 2026-06-09 | Aligned testing logger with core log levels. | `packages/fulframe_testing/lib` | Reused `LogLevel` for recording logger. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
