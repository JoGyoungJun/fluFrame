# story-write-readme-positioning

Status: Complete
Epic: `production/epics/presentation/EPIC-open-source-readiness.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Config/Data
Priority: High

## Goal

Update the root README so a new contributor can quickly understand FulFrame's
purpose, current MVP shape, and first local setup commands.

## Acceptance Criteria

- [x] Given a new contributor opens the repository, when they read the README,
      then they understand that FulFrame prevents rebuilding common Flutter
      app-foundation features for every app.
- [x] Given a developer wants to inspect the current MVP, when they read the
      README, then they can find the package layout, starter app, and feature
      module guide.
- [x] Given a developer wants to verify the repository locally, when they read
      the README, then they can find bootstrap, analyze, and test commands.
- [x] Given the project is early-stage, when the README is read, then it avoids
      overstating release or package-publishing readiness.

## Implementation Notes

- Relevant files: `README.md`, `docs/mvp-plan.md`,
  `docs/feature-module-guide.md`, `docs/flutter-setup.md`.
- Constraints: do not claim pub.dev availability or production stability.
- Non-goals: license selection, contribution templates, release automation.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| README review | `README.md` | Yes |
| Workspace analyze | `dart run melos run analyze` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-10 | Rewrote root README for MVP contributor orientation. | `README.md` | Explains purpose, current status, packages, starter feature, setup, and open questions. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
