---
name: cycle
description: Run one full development cycle in a single command — resume or plan the milestone, work every READY issue through PR+CI sequentially, gate the release, and close with a retro.
argument-hint: "[milestone] [max issues] [release]"
---

The whole fluFrame routine in one invocation:
`/plan → /work × N → (/release) → /retro`. This is an orchestrator — each
phase follows its own skill's rules; this file only defines the sequencing,
the pauses, and the stop conditions.

## Arguments

- `[milestone]` — target milestone title; omit to auto-resolve.
- `[max issues]` — cap on issues worked this cycle (default: all READY).
- `release` — include the pub.dev release phase when the milestone
  completes (otherwise it is offered, not run).

## Phase 0 — Preflight

Working tree clean, on up-to-date `main`, last CI run on main green
(`gh run list --limit 1`). Anything off → fix or stop; never start a
cycle on a red base. State the cycle scope up front: milestone, issue
count, caps.

## Phase 1 — Milestone (pause point #1)

An open milestone with open issues → resume it (report progress so far).
None → run the `/plan` flow. Either way the user approves the worked
issue list ONCE here — this is the only mandatory pause before the work
loop. The cycle never invents scope: only issues already in the approved
milestone are worked.

## Phase 2 — Work loop (sequential, autonomous)

Repeat until no READY issues remain, the cap is hit, or a stop condition
fires. For each iteration, pick the highest-priority READY issue
(P0 → P1 → P2) and run the full `/work` flow:

1. Readiness gate. NEEDS WORK with minor gaps (missing out-of-scope
   note, unlabeled type) → fix the issue text via `gh issue edit` and
   proceed. Missing/untestable acceptance criteria or BLOCKED → **skip**,
   record the reason, move on — the cycle never authors its own
   acceptance criteria to unblock itself.
2. Branch → implement with tests → `/verify` (`fast`; full when
   `packages/fluframe/` or the generation contract is touched).
3. PR with `Closes #<n>` → `gh pr merge --squash --auto --delete-branch`
   → `gh pr checks <pr> --watch` until merged (PRs land strictly one at
   a time: branch protection requires up-to-date branches, so parallel
   PRs would just invalidate each other).
4. `git checkout main && git pull` before the next iteration.

**Failure rule**: a red `/verify` or CI gets ONE fix attempt; still red →
abandon the branch (main stays intact), mark the issue as failed with
the error, and continue with the next issue. TWO consecutive issues
failing → stop the whole loop and report — that pattern means something
systemic broke.

## Phase 3 — Release gate (pause point #2)

When every P0 in the milestone is closed: with the `release` argument
run the `/release` flow; otherwise ask. `/release` pauses on its own
interactive `dart pub publish` step regardless — the user runs it with
the `!` prefix, then the cycle finishes the tag via the PR flow. P0s
still open → skip release, say why.

## Phase 4 — Retro

Run `/retro` for the milestone: land the retro doc via PR, close the
milestone (`gh api -X PATCH .../milestones/<n> -f state=closed`), link
the retro from its description.

## Phase 5 — Cycle report

One table: issue → outcome (merged PR # / skipped+reason / failed+error),
then release status, retro link, and the suggested next step
(`/plan` for the next milestone, or the blockers to clear first).

## Continuous operation

For an ongoing loop across time, pair with the harness-level scheduler:
`/loop /cycle` re-invokes this skill on an interval — each run picks up
wherever the milestone stands. Sessions are resumable because all state
lives in GitHub (milestones, issues, PRs), never in the conversation.
