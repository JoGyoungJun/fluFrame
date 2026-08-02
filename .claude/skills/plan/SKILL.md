---
name: plan
description: Plan the next fluFrame milestone — gather repo/community state, feed forward retro action items, propose a goal + prioritized issue list, verify P0 readiness, and set up the GitHub milestone.
argument-hint: "[milestone title, e.g. v0.2.0]"
---

Milestone planning: GitHub milestones are the plan of record (there are
no local plan files). A milestone = one release or one coherent goal.

## 1. Gather state (data, not vibes)

```sh
gh api repos/JoGyoungJun/fluFrame/milestones --jq '.[] | {title, open_issues, closed_issues, due_on}'
gh issue list --state open --limit 100
gh pr list --state open
gh run list --limit 5
```

Plus: the latest retro in `docs/retrospectives/` (its action items MUST
appear in this plan or be explicitly dropped with a reason; skip if no
retro exists yet), and current adoption numbers when relevant (pub.dev
downloads/score).

## 2. Propose the milestone (draft in conversation first)

- **Goal**: one sentence a stranger understands ("v0.2.0: golden tests +
  theming presets").
- **Issue list**: existing issues to pull in + new issues to create, each
  with a priority label (`P0` must-ship / `P1` should / `P2` nice) and a
  size guess (S/M/L). Keep the P0 set small enough to actually ship.
- **Non-goals / deferred**: name what was consciously left out.
- A milestone due date only if it is real.

## 3. Readiness gate on P0s

Every P0 issue must pass the `/work` readiness checklist (testable
acceptance criteria, no unresolved dependencies, spec/ADR where the
`/design` rules require one). A P0 that is not READY gets a prominent
warning: fix the issue or demote it — never start a milestone with vague
must-ships.

## 4. Apply (after user approval)

```sh
# One-time bootstrap: priority labels (idempotent thanks to --force)
gh label create P0 --color B60205 --description "must-ship" --force
gh label create P1 --color D93F0B --description "should-have" --force
gh label create P2 --color FBCA04 --description "nice-to-have" --force

gh api -X POST repos/JoGyoungJun/fluFrame/milestones -f title=<t> -f description=<goal>
gh issue create ... --milestone <t>        # new issues
gh issue edit <n> --milestone <t> --add-label P0
```

Note: `gh` has no first-class milestone command — create/close milestones
via `gh api`, assign via `gh issue edit --milestone`.

## 5. Report

Plan summary table (issue / priority / size / ready?), the goal sentence,
carried-forward retro items, and the first `/work` candidate to start on.
