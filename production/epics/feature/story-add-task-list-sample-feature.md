# story-add-task-list-sample-feature

Status: Complete
Epic: `production/epics/feature/EPIC-template-app.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Integration
Priority: High

## Goal

Add a small local-only task-list feature to the starter app so contributors can
see the FulFrame architecture in a realistic module.

## Acceptance Criteria

- [x] Given the starter app launches, when the user opens it, then a task-list
      screen renders without backend setup.
- [x] Given the task list has no items, when the screen renders, then it uses
      FulFrame's empty-state pattern.
- [x] Given a task is added locally, when the add action completes, then the UI
      shows the new task.
- [x] Given the feature source is inspected, when contributors read it, then
      `ui`, `application`, `domain`, and `data` boundaries are clear.
- [x] Given tests run, when workspace tests execute, then the task-list feature
      has unit or widget evidence.

## Implementation Notes

- Relevant files: `examples/starter_app/lib`, `examples/starter_app/test`,
  `packages/fulframe_app`, `packages/fulframe_testing`.
- Use an in-memory repository in MVP.
- Do not add backend, persistence, auth, or generated code.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| Workspace analyze | `dart run melos run analyze` | Yes |
| Workspace tests | `dart run melos run test` | Yes |
| Feature docs | `docs/feature-module-guide.md` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-09 | Added local-only task-list sample feature. | `examples/starter_app/lib/features/task_list` | Uses domain/application/data/ui boundaries and in-memory data. |
| 2026-06-09 | Added FulFrame state widgets. | `packages/fulframe_app/lib/src/fulframe_state_widgets.dart` | Starter feature uses the empty state pattern. |
| 2026-06-09 | Added feature module guide. | `docs/feature-module-guide.md` | Documents layer responsibilities and MVP rules. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
