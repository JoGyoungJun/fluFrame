# story-add-contribution-docs

Status: Complete
Epic: `production/epics/presentation/EPIC-open-source-readiness.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Config/Data
Priority: High

## Goal

Add basic open-source contribution documents so new contributors know how to
propose changes, report issues, and open pull requests.

## Acceptance Criteria

- [x] Given a contributor wants to help, when they open `CONTRIBUTING.md`, then
      they can find local setup, quality checks, story workflow expectations,
      and PR expectations.
- [x] Given a contributor wants to report a bug or request a feature, when they
      open GitHub issue templates, then they can choose an appropriate template.
- [x] Given a contributor opens a pull request, when they use the PR template,
      then they are prompted for summary, verification, and related story/GDD.
- [x] Given the MIT license is selected, when contribution docs are read, then
      they point contributors to the repository license.

## Implementation Notes

- Relevant files: `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE/`,
  `.github/pull_request_template.md`, `production/session-state/active.md`.
- Constraints: keep docs truthful for an early-stage project; preserve the GDD
  -> epic -> story workflow.
- Non-goals: adding a code of conduct, adding automation.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| Contribution docs review | `CONTRIBUTING.md` | Yes |
| Issue templates review | `.github/ISSUE_TEMPLATE/` | Yes |
| PR template review | `.github/pull_request_template.md` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-10 | Added contribution docs and GitHub templates. | `CONTRIBUTING.md`, `.github/ISSUE_TEMPLATE`, `.github/pull_request_template.md` | Includes local setup, workflow, bug/feature templates, and PR checklist. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
