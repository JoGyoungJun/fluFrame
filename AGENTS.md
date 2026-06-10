# fulFrame Agent Instructions

This project uses a file-backed production workflow adapted from
Claude-Code-Game-Studios. For this repository, treat GDD as a system spec
document for the Flutter open-source app framework, not only as a game design
document.

## Session Recovery

At the start of any work session:

1. Read `production/session-state/active.md`.
2. Read active files listed in that document.
3. Continue from the next incomplete item unless the user gives a new priority.

Update `production/session-state/active.md` after every significant milestone:
GDD section written, epic created, story created, implementation step completed,
test result obtained, blocker found, or focus changed.

## Production Workflow

Use this order for product and framework work:

1. Write or update a GDD in `design/gdd/`.
2. Mark the GDD `Approved` only after acceptance criteria and open questions are clear.
3. Convert approved GDDs into epics under `production/epics/<layer>/`.
4. Break each epic into story files.
5. Implement one story at a time.
6. Verify acceptance criteria.
7. Mark the story complete and update session state.

The local Codex skill `.codex/skills/game-production-pipeline/SKILL.md` contains
the detailed operating rules.

## Key Paths

- `production/session-state/active.md`: current task, progress, decisions, open questions.
- `design/gdd/systems-index.md`: index of all planned systems and their status.
- `design/gdd/*.md`: framework system specs.
- `production/epics/<layer>/EPIC-*.md`: epic plans.
- `production/epics/<layer>/story-*.md`: implementation stories.
- `docs/templates/`: templates for GDDs, epics, stories, and session state.

## Implementation Discipline

- Do not implement broad features directly from conversation only.
- Prefer creating or updating a GDD, epic, and story before writing code.
- Keep code changes scoped to the active story.
- Preserve traceability from code work back to the story, epic, and GDD.
- Record verification commands and outcomes in the active story or session state.
