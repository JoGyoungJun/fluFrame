# Architecture Decision Records

Significant technical decisions in fluFrame are recorded here as ADRs —
short documents capturing the context, the decision, the alternatives that
were considered, and the consequences. They are the project's public
decision log: contributors can see *why* things are the way they are
without archaeology through PR threads.

## When to write one

Write an ADR when a decision is hard to reverse or shapes future work:
adding/replacing a core dependency, changing the template's architecture
patterns, changing the CLI's generation contract, changing release or
support policy. Small implementation choices do not need one.

## How

1. Copy `0000-template.md` to `NNNN-short-slug.md` (next free number).
2. Fill it in — keep it under a page.
3. Land it in the same PR as the change it explains (or its own PR for
   pure policy decisions).

Statuses: `Proposed` → `Accepted` | `Rejected`; later `Superseded by
[NNNN](NNNN-slug.md)` if replaced.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-backend-addon-overlays.md) | Backend addons as anchored patch overlays | Accepted |
