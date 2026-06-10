# EPIC-project-scaffold

Status: In Progress
Layer: foundation
Source GDD: `design/gdd/flutter-app-framework.md`
Priority: MVP

## Goal

Create the repository structure, package layout, tool configuration, and baseline
automation needed for a Flutter open-source framework.

## Scope

### In Scope

- Flutter/Dart monorepo package layout.
- `packages/`, `examples/`, `docs/`, and `tool/` directories.
- Baseline analyzer/lint configuration.
- Basic CI plan for format, analyze, and tests.

### Out Of Scope

- Publishing to pub.dev.
- App store release automation.
- Backend integrations.

## Requirements From GDD

| ID | Requirement | Acceptance Source | Notes |
|----|-------------|-------------------|-------|
| FF-MVP-001 | Compilable Flutter starter app foundation. | GDD Acceptance Criteria | Needs Flutter scaffold later. |
| FF-MVP-002 | Package structure for core/app/testing/lints. | GDD MVP Requirements | Monorepo-first. |
| FF-MVP-005 | CI for analyze, format, and tests. | GDD MVP Requirements | GitHub Actions preferred for open source. |

## Stories

| Story | Type | Status | Evidence |
|-------|------|--------|----------|
| `story-create-monorepo-layout.md` | Config/Data | Complete | Directory tree and generated package files. |
| `story-add-analysis-and-lints.md` | Config/Data | Planned | `flutter analyze` passes. |
| `story-add-ci-quality-gate.md` | Integration | Planned | CI workflow runs format/analyze/test. |

## Definition Of Done

- [ ] Package directories exist and are intentionally named.
- [ ] Example app location is defined.
- [ ] Analyzer and lint defaults are present.
- [ ] CI quality gate is documented or implemented.
