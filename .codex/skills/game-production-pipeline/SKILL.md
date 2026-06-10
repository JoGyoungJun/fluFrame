---
name: game-production-pipeline
description: "Use when planning or building this repository through a file-backed production workflow: create or update GDD system specs for the Flutter app framework, convert approved specs into epics, break epics into implementation stories, implement one story at a time, and preserve progress across Codex sessions in production/session-state/active.md."
---

# Game Production Pipeline

Use this workflow for framework design and implementation tasks in this repository.
The project memory is on disk, not in the conversation.

## Start Every Session

1. Read `production/session-state/active.md` if it exists.
2. Read any active GDD, epic, story, or implementation files listed there.
3. Continue from the next incomplete checklist item unless the user changes direction.
4. Update `production/session-state/active.md` after each meaningful milestone.

If `active.md` does not exist, create it from `docs/templates/session-state-template.md`
before starting production work.

## Workflow

Follow this order unless the user explicitly asks for a smaller task:

1. GDD: write or update a system spec in `design/gdd/`.
2. Approval: mark the GDD `Approved` only when open questions and acceptance criteria are clear.
3. Epic: create an epic in `production/epics/<layer>/EPIC-<system>.md`.
4. Story: create story files under the same epic folder.
5. Implementation: implement exactly one story at a time.
6. Verification: run the relevant checks and record evidence in the story.
7. Completion: mark the story complete and update session state.

## Required Files

- GDD index: `design/gdd/systems-index.md`
- GDD template: `docs/templates/gdd-template.md`
- Epic template: `docs/templates/epic-template.md`
- Story template: `docs/templates/story-template.md`
- Session state: `production/session-state/active.md`

## GDD Rules

- GDDs define behavior before implementation.
- Each GDD must include summary, developer/user value, rules, interactions,
  extension points, UI/API requirements, acceptance criteria, and open questions.
- Do not create epics from GDDs with status `Draft` or `In Review` unless the user
  explicitly asks for speculative planning.

## Epic Rules

- Create one epic per approved system or tightly scoped feature area.
- Put epics in one of these layers: `foundation`, `core`, `feature`, `presentation`.
- Each epic must trace back to its source GDD and list requirements, dependencies,
  risks, and Definition of Done.

## Story Rules

- Stories must be small enough to implement and verify in one focused pass.
- Each story must include acceptance criteria and evidence requirements.
- Classify stories as `Logic`, `Integration`, `UI`, `Visual/Feel`, or `Config/Data`.
- Do not start implementation while a story has ambiguous acceptance criteria.

## Implementation Rules

- Read the story, source GDD, and epic before editing code.
- Update the active session state before and after implementation.
- Keep implementation scoped to the active story.
- Record changed files, verification commands, results, blockers, and next steps in
  `production/session-state/active.md`.
