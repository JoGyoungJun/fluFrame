---
name: adr
description: Record a significant technical decision as an Architecture Decision Record in docs/adr/ — context, decision, honest alternatives, consequences, and index update.
argument-hint: "<decision title>"
---

Write an ADR for a decision that is hard to reverse or shapes future
work: adding/replacing a core dependency, changing template architecture
patterns, changing the CLI generation contract, changing release/support
policy. Small implementation choices do not get ADRs.

## Steps

1. **Gather context**: the triggering issue/PR/design spec, the current
   state in code, and any prior ADR this would supersede (scan the
   `docs/adr/README.md` index).
2. **Draft** from `docs/adr/0000-template.md` into `NNNN-<slug>.md`
   (next free number). Requirements:
   - **Context** states the forces honestly, including what breaks if we
     do nothing.
   - **Decision** is active and checkable: "We will pin build_runner to
     ^2.15.1 until freezed supports analyzer 13+", not "we should
     consider".
   - **Alternatives**: at least two real ones, each with the actual
     reason it lost — no strawmen.
   - **Consequences** include the costs and any follow-up work, filed as
     issues.
3. **Skeptic self-review before marking Accepted** (author = reviewer in
   a solo project, so be adversarial with yourself): (a) is the cited
   problem actually reachable, (b) does an existing mechanism already
   solve it, (c) re-verify every version number/claim against pub.dev or
   the code — not from memory, (d) does every API the ADR cites actually
   exist in the pinned versions.
4. **Status**: `Proposed` while under discussion → `Accepted` when the
   change lands. Never silently rewrite an Accepted ADR's decision. There
   are two sanctioned ways to change one, and this repo uses both:
   - **Amend in place** when experience corrected a detail but the
     decision still holds. Append a dated `## Amendment: <what changed>`
     section that says what the original got wrong, and mark the status
     `Accepted (amended <date> — see <section>)`. ADRs 0001 and 0002 both
     do this.
   - **Supersede** with a new ADR when the decision itself is reversed.
     Set the old one to `Superseded by NNNN` and cross-link both.
5. **Land it**: update the index table in `docs/adr/README.md`, then
   include the ADR in the same PR as the change it explains (own PR for
   pure policy). If the decision affects day-to-day rules, mirror the
   rule (one line) into CLAUDE.md's hard rules.
