---
name: retro
description: Milestone retrospective — plan-vs-actual from GitHub data, OSS adoption metrics, previous action-item follow-up, and 3-5 owned action items feeding the next /plan.
argument-hint: "[milestone title]"
---

Compare what the milestone planned against what actually happened, and
turn the difference into a handful of concrete improvements. Data comes
from GitHub — never from memory.

## 1. Load data

```sh
gh api "repos/JoGyoungJun/fluFrame/milestones?state=all" --jq '.[] | {title, open_issues, closed_issues}'
gh issue list --milestone "<title>" --state all --json number,title,state,labels,closedAt
gh pr list --state merged --limit 50 --json number,title,mergedAt,author
gh run list --limit 20
```

Classify milestone issues into: completed as planned / completed with
scope change / carried over (still open) / added mid-milestone /
consciously dropped. Also grep `TODO|FIXME|HACK` counts across
`template/` and `packages/fluframe/` and compare with the previous
retro's counts.

## 2. OSS metrics (ties to the Claude for OSS goal)

PRs merged (maintainer vs external authors), new external contributors,
CI pass rate on main, and pub.dev downloads/score (WebFetch
https://pub.dev/packages/fluframe). Record absolute numbers with dates so
trends are visible across retros.

## 3. Previous action items

Read the newest file in `docs/retrospectives/` (if none exists yet —
first retro — say so and skip this step). Every previous action item
gets a verdict: DONE / NOT DONE (why) / OBSOLETE. An item that is
NOT DONE twice in a row is a process smell — say so explicitly.

## 4. Write `docs/retrospectives/YYYY-MM-<milestone-slug>.md`

Fixed outline: Metrics table → What went well → What went poorly (system
causes, never blame) → Previous action items follow-up → **Action items
(3-5 hard cap, each with an owner and a deadline)** → One-paragraph
summary. Action items that are real work become GitHub issues
(`gh issue create`) so they cannot silently evaporate.

## 5. Close the loop

Land the retro via the normal PR flow, then link it from the closed
milestone (milestones cannot be commented on — append to the
description instead):

```sh
gh api -X PATCH repos/JoGyoungJun/fluFrame/milestones/<number> \
  -f description="<existing goal> | Retro: docs/retrospectives/<file> — <one-line summary>"
```

Finally offer to run `/plan` for the next milestone with the action
items pre-loaded.
