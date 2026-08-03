# 0002 — Upgrades via three-way merge against reconstructed bases

- **Status**: Accepted
- **Date**: 2026-08-03
- **Related**: design spec 002, issues #80 #81, milestone v0.14.0

## Context

Generated apps diverge from the template the moment users touch them, so
"upgrade" must reconcile three states: what the template WAS when the
app was generated, what the template IS now, and what the user has. Any
strategy that ignores one of the three either destroys user work or
cannot apply upstream changes. Published fluframe versions permanently
archive their template bundle inside the package tarball on pub.dev —
which makes the historical BASE reproducible on demand.

## Decision

We will implement `fluframe upgrade` as a per-file **three-way merge**:

- **BASE**: the template bundle extracted from the pub.dev archive of
  the version recorded in `.fluframe.json`, run through a new *bare
  overlay* generation mode (overlay + token rewrite + the recorded addon
  combo; no flutter create, no pub) so it is byte-comparable.
- **THEIRS**: the same bare generation from the currently installed
  bundle.
- **OURS**: the user's working tree.
- Engine: `git merge-file` (battle-tested, conflict markers users
  already understand). Dry-run is the default; `--apply` writes.
- Generation metadata (`.fluframe.json`) becomes part of the create
  contract from v0.14.0 onward; older apps supply `--from` manually.

## Alternatives considered

- **Overwrite with current template** — destroys every user change;
  a non-starter.
- **Replay recorded patches (migration scripts per version)** — precise
  but demands hand-written migrations for every release forever; the
  maintenance cost is exactly what a small project cannot pay.
- **No upgrade (status quo)** — the pain this ADR exists to end; also
  locks 1.0.0 into an upgrade-less contract.

## Consequences

- pub.dev archives become part of the upgrade contract: bundles must
  never be stripped from published versions (already guarded by the
  slash-anchored `.pubignore` rule and the e2e).
- A new runtime dependency (`package:archive`) for tarball extraction.
- Conflicts are possible and expected — surfaced as standard git
  markers rather than hidden; the report tells users exactly which
  files need attention.
- `cliVersion` moves to `lib/src/version.dart`; release tooling and
  docs update their sed targets once.
