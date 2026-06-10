# EPIC-framework-core

Status: Draft
Layer: core
Source GDD: `design/gdd/flutter-app-framework.md`
Priority: MVP

## Goal

Define the framework's core contracts and architectural boundaries so app
features can be built consistently without locking developers into one backend
or state-management package.

## Scope

### In Scope

- `fulframe_core` contracts.
- Layer boundary conventions.
- Result/error/config/logger abstractions.
- Minimal examples that show how UI/application/domain/data interact.

### Out Of Scope

- Full state-management package integration.
- Backend adapters.
- Complex code generation.

## Requirements From GDD

| ID | Requirement | Acceptance Source | Notes |
|----|-------------|-------------------|-------|
| FF-MVP-003 | Define architecture contracts and folder conventions. | GDD MVP Requirements | Based on Flutter UI/data separation. |
| FF-MVP-004 | Include test examples. | GDD MVP Requirements | Unit tests first. |

## Stories

| Story | Type | Status | Evidence |
|-------|------|--------|----------|
| `story-define-core-contracts.md` | Logic | Complete | Unit tests for core contracts. |
| `story-document-layer-boundaries.md` | Config/Data | Planned | Architecture doc with import rules. |
| `story-add-feature-module-example.md` | Integration | Planned | Example feature compiles and tests. |

## Definition Of Done

- [ ] Core contracts are documented.
- [ ] Core contracts are covered by unit tests.
- [ ] Layer boundaries are clear enough for contributors to follow.
- [ ] No MVP contract requires a specific backend.
