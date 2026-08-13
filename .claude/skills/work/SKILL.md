---
name: work
description: Implement a GitHub issue end-to-end — readiness gate (READY / NEEDS WORK / BLOCKED), branch, implementation with tests, /verify, PR with auto-merge, and next-issue handoff.
argument-hint: "<issue#>"
---

Issue-driven implementation: the fluFrame unit of work is a GitHub
issue, and this skill takes one from "assigned" to "merged".

## 1. Readiness gate (before writing any code)

`gh issue view <n>` and check:

- **Acceptance criteria** exist and are testable/observable (no "works
  correctly", no TBD/TODO/? markers).
- **Scope** is clear: what is out of scope is stated or obvious; size
  fits one PR (if not — propose splitting the issue first).
- **Dependencies**: "blocked by #N" issues are closed; referenced files
  exist; if the change touches post-cutoff APIs (Riverpod 3, freezed 3,
  Flutter 3.44), the relevant CLAUDE.md note covers it or verification
  is planned.
- **Design**: per `/design` rules — Feature-sized needs a spec in
  `docs/design/`, architecture-shaping needs an ADR. Tuning/tweak needs
  neither.

Verdict: **READY** → proceed. **NEEDS WORK** → draft the missing issue
sections in conversation and offer to apply via `gh issue edit`; do not
start coding around gaps. **BLOCKED** → stop, name the blocker, suggest
another READY issue.

## 2. Implement

- Branch: `feat/<n>-<slug>` or `fix/<n>-<slug>` from up-to-date main.
- Follow the conventions: `/new-feature` for template feature modules,
  CLAUDE.md hard rules always (rename tokens, l10n in all three ARBs —
  en + ja + ko, committed codegen, package imports).
- **Tests are part of the change**: a bug fix ships a regression test
  that fails before the fix; a feature ships unit + widget tests
  including the error path.

## 3. Verify

`/verify` — full when the CLI or generation contract is touched, `fast`
otherwise. Never open a PR red.

## 4. Land

```sh
git push -u origin <branch>
gh pr create --fill --body "...Closes #<n>..."
gh pr merge --squash --auto --delete-branch
```

PR body: what/why, "Closes #<n>", and the acceptance criteria as a
checked checklist (each one actually verified, not decoratively ticked).
After the merge confirm the issue auto-closed; comment on it if any
criterion was consciously deferred.

## 5. Handoff

Surface up to 3 other READY issues from the current milestone (priority
first) as next candidates; if none, say so and suggest `/plan` or
`/oss-triage`.
