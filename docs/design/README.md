# Design specs

Lightweight design documents for non-trivial features, written **before**
implementation. A spec answers "what are we building and how will we know
it works" in one or two pages — it is not a formality; implementation PRs
for specced features link back to their spec.

## When a spec is required

- New template feature module or significant change to an existing one
- New CLI command or a change to the generation contract
- Anything touching the rename-token or l10n conventions

Bug fixes and mechanical changes skip specs entirely.

## Format

`NNN-short-slug.md` with the sections produced by the `/design` skill:
Problem, Goals / Non-goals, Design (UX + API surface + data), l10n keys,
Test plan, Acceptance criteria, Open questions.

## Index

| # | Spec | Status | Issue |
|---|---|---|---|
| 001 | [Backend-neutral auth scaffold](001-auth-scaffold.md) | APPROVED | #24 #25 #26 |
| 002 | [fluframe upgrade](002-upgrade-command.md) | APPROVED | #80 #81 |
