# EPIC-template-app

Status: Draft
Layer: feature
Source GDD: `design/gdd/flutter-app-framework.md`
Priority: MVP

## Goal

Create a starter Flutter app that demonstrates FulFrame architecture in a small,
realistic feature.

## Scope

### In Scope

- Example app shell.
- One sample feature.
- Routing, theming, configuration, and error display examples.
- Unit and widget tests for the sample feature.

### Out Of Scope

- Authentication.
- Remote backend integration.
- Store deployment.

## Requirements From GDD

| ID | Requirement | Acceptance Source | Notes |
|----|-------------|-------------------|-------|
| FF-MVP-001 | New developer can run the example app. | GDD Acceptance Criteria | Must work without external services. |
| FF-MVP-004 | Unit, widget, and smoke-test examples. | GDD MVP Requirements | Keep tests small. |
| FF-MVP-007 | Docs for creating a new feature module. | GDD MVP Requirements | Derive from sample feature. |

## Stories

| Story | Type | Status | Evidence |
|-------|------|--------|----------|
| `story-create-starter-app-shell.md` | UI | Planned | App launches locally. |
| `story-add-sample-feature.md` | Integration | Planned | Feature uses declared layer boundaries. |
| `story-add-task-list-sample-feature.md` | Integration | Complete | Task-list feature demonstrates MVP architecture. |
| `story-add-feature-module-guide.md` | Config/Data | Planned | Docs explain how to add a feature. |

## Definition Of Done

- [ ] Example app launches.
- [ ] Sample feature demonstrates the framework architecture.
- [ ] Tests cover the sample feature.
- [ ] Documentation explains how to extend it.
