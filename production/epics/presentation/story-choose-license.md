# story-choose-license

Status: Complete
Epic: `production/epics/presentation/EPIC-open-source-readiness.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Config/Data
Priority: High

## Goal

Add the selected open-source license so contributors and users can understand
the repository's usage terms before the first public commit.

## Acceptance Criteria

- [x] Given a user reviews the repository, when they open `LICENSE`, then they
      can see the selected MIT license terms.
- [x] Given a contributor reads project docs, when license status is mentioned,
      then it is described as MIT rather than unresolved.
- [x] Given production planning files are inspected, when open-source readiness
      status is reviewed, then license selection is no longer blocked.

## Implementation Notes

- Selected license: MIT.
- Copyright holder line: `Copyright (c) 2026 FulFrame contributors`.
- Non-goals: legal advice, CLA setup, package publishing.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| License file | `LICENSE` | Yes |
| Docs mention MIT | `README.md` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-10 | Added MIT license. | `LICENSE`, `README.md`, planning docs | User selected MIT. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
