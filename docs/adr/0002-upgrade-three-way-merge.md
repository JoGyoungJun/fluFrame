# 0002 — Upgrades via three-way merge against reconstructed bases

- **Status**: Accepted (amended 2026-08-06 — see *Amendment: apply
  safety*)
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

## Amendment: apply safety (2026-08-06)

Shipping 1.1.0 exposed three ways `--apply` could damage an app without
saying so. The merge strategy above is unchanged; these constrain it.

- **The merged bytes never cross a pipe.** `git merge-file` is invoked
  without `-p`, so git writes the result into the OURS temp file and
  fluframe reads it back. Reading merged content from stdout meant it was
  decoded with the OS codepage (cp949 on Korean Windows), which silently
  destroyed every non-ASCII character in the user's files — and, on a
  hard merge error, overwrote them with empty output.
- **`--apply` requires an undo.** It rewrites files in place and keeps no
  backup, while `flutter create` does not `git init`. So `--apply`
  refuses unless the app is a git repository with a clean working tree.
  `--force` opts out for users who have their own safety net (a container,
  a copy, an editor's local history).
- **Deletions are symmetric.** The original decision promised never to
  delete a file on the user's behalf; restoring one is the same overreach
  in reverse. A file present in BASE but missing locally was
  indistinguishable from a new file, so `--apply` brought deleted files
  back — and a *renamed* one back beside its copy, declaring the same
  class twice. Such files are now reported as `deleted locally - not
  restored`, with `--restore-deleted` to opt in.
- **Each bundle carries its own addon definitions.** BASE is rebuilt by
  replaying the recorded addon patches, whose anchors are exact strings
  from the template of that era. Replaying the *current* CLI's anchors
  against an archived bundle broke as soon as the template moved one of
  those lines, and the upgrade aborted at exit 70 for every app that used
  any addon. Bundles now ship `templates/addons.json`; when it is absent
  (every version through 1.1.0) or the addons cannot be replayed anyway,
  both sides are rebuilt without addons and the report says so.
- **`.fluframe.json` advances only on a fully clean result.** Recording
  the new version while conflict markers are still in the tree made the
  `already up to date` short-circuit permanent: the only escape was
  hand-editing the metadata. Conflicts now leave the recorded version
  alone and exit non-zero, so a re-run after resolution works and CI can
  see the failure.
