---
name: design
description: Write a design spec before implementing a non-trivial change — size classification, context scan, spec document with testable acceptance criteria, and an APPROVED / NEEDS REVISION verdict.
argument-hint: "<title or issue#>"
---

Produce the design layer of the fluFrame dev routine: nothing meaningful
gets implemented spec-less, but small changes are not bureaucratized.

## 1. Classify the change (confirm with the user)

- **Tuning/Tweak** — config value, copy change, small behavior fix with no
  new states: NO spec. Write testable acceptance criteria directly into
  the GitHub issue and go to `/work`.
- **Feature** — new module, new CLI option, new user-visible behavior:
  spec required (this skill).
- **Architecture-shaping** — new/replaced dependency, changed generation
  contract, changed conventions: spec required AND pair with `/adr`.

## 2. Context scan (before drafting)

Read the linked issue, related code in `template/` or
`packages/fluframe/`, any prior specs in `docs/design/` touching the same
area, and CLAUDE.md's hard rules (rename tokens, l10n, dependency-light).
Report what was found and any conflict.

## 3. Draft `docs/design/NNN-<slug>.md`

Sections, all required (write "None" explicitly rather than omitting):

1. **Problem** — who hits what, link the issue.
2. **Goals / Non-goals** — the boundary is the point.
3. **Design** — UX (screens/flows), API surface (providers, classes,
   CLI flags), data (models, storage keys). Precise enough to implement
   without guessing.
4. **l10n keys** — every new user-facing string, with en + ja + ko values
   (the template ships all three locales).
5. **Test plan** — which unit/widget/e2e tests will exist and where.
6. **Acceptance criteria** — checkboxes, each an observable testable
   condition. "Works correctly" is banned; "tapping Retry after a failed
   load shows the list within one frame of success" is the bar.
7. **Open questions** — must be empty (or explicitly deferred with an
   owner) before implementation starts.

## 4. Review gate

Self-check the draft against: completeness (all 7 sections), internal
consistency, implementability, CLAUDE.md rule compliance. For large specs
(new module, CLI contract change), additionally spawn 2-3 adversarial
reviewer subagents ("find what is wrong or underspecified — do not
validate") plus one skeptic pass that tries to refute their findings;
only upheld findings block. Verdict: **APPROVED / NEEDS REVISION** (loop
until approved).

## 5. Land it

Add the spec to the `docs/design/README.md` index, comment the spec link
on the issue (`gh issue comment`), and include the spec in the
implementation PR (or its own PR if implementation is deferred). Then
hand off to `/work <issue#>`.
