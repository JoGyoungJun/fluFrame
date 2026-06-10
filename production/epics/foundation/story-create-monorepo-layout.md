# story-create-monorepo-layout

Status: Complete
Epic: `production/epics/foundation/EPIC-project-scaffold.md`
Source GDD: `design/gdd/flutter-app-framework.md`
Type: Config/Data
Priority: High

## Goal

Create the initial Flutter framework monorepo layout without yet implementing
package internals.

## Acceptance Criteria

- [x] Given a fresh checkout, when a contributor opens the repository, then the
      intended package and example app structure is clear from directory names.
- [x] Given the GDD package shape, when the scaffold is created, then
      `packages/fulframe_core`, `packages/fulframe_app`,
      `packages/fulframe_testing`, `packages/fulframe_lints`, and
      `examples/starter_app` exist or are explicitly deferred with reason.
- [x] Given this is an open-source project, when the scaffold is created, then
      docs and tool directories exist for future contribution and automation.

## Implementation Notes

- Relevant files: repository root, `packages/`, `examples/`, `docs/`, `tool/`.
- Constraints: do not add package dependencies until package strategy is decided.
- Non-goals: no Flutter code implementation in this story.

## Evidence Required

| Evidence | Path or Command | Required |
|----------|-----------------|----------|
| Directory listing | `Get-ChildItem -Force -Recurse -Depth 2` | Yes |

## Work Log

| Date | Change | Files | Notes |
|------|--------|-------|-------|
| 2026-06-09 | Created initial monorepo scaffold. | `packages/`, `examples/`, `docs/`, `tool/`, root config files | Flutter and Dart CLIs were not available on PATH, so generated files were created manually. |
| 2026-06-09 | Added initial CI workflow. | `.github/workflows/quality.yml` | Uses stable Flutter in GitHub Actions. |

## Completion Checklist

- [x] Story acceptance criteria are met.
- [x] Relevant checks were run.
- [x] Evidence is recorded.
- [x] Session state is updated.
