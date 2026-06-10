# story-add-code-of-conduct

Status: Complete
Epic: `production/epics/presentation/EPIC-open-source-readiness.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Config/Data
Priority: Medium

## Goal

Add a basic code of conduct so the repository has clear participation
expectations before public contribution.

## Acceptance Criteria

- [x] Given a contributor opens `CODE_OF_CONDUCT.md`, when they read it, then
      they can find expected and unacceptable behavior.
- [x] Given a maintainer needs to handle a report, when they read the document,
      then they can find a basic enforcement and reporting path.
- [x] Given the project is early-stage, when the document is read, then it does
      not imply a larger moderation team or process than exists.

## Implementation Notes

- Relevant files: `CODE_OF_CONDUCT.md`,
  `production/epics/presentation/EPIC-open-source-readiness.md`.
- Use project-specific plain language instead of importing a full external
  template.
- Non-goals: private reporting infrastructure, moderation automation.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| Code of conduct review | `CODE_OF_CONDUCT.md` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-10 | Added code of conduct. | `CODE_OF_CONDUCT.md` | Plain project-specific expectations and reporting path. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
