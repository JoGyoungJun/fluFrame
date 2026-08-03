# 0001 — Backend addons as anchored patch overlays

- **Status**: Accepted
- **Date**: 2026-08-03
- **Related**: design spec 001 (auth scaffold), issue #35, milestone v0.4.0

## Context

The auth scaffold (v0.3.0) left one seam — `authRepositoryProvider` — for
real backends. Shipping `--backend supabase|firebase` requires the CLI to
produce a *variant* of the template while keeping fluFrame's guarantees:
the base template stays dependency-light, every generated variant passes
`flutter analyze` + `flutter test`, and there is exactly one template to
maintain. Doing nothing keeps backend wiring a manual guide-following
exercise (docs/guides/), which is the biggest onboarding cliff left.

## Decision

We will model a backend addon as three deterministic primitives applied
after the base overlay:

1. **Dependencies** — installed with `flutter pub add` (real version
   resolution, sorted insertion, no pins to maintain).
2. **Addon files** — bundled under `template_addons/<name>/` in the repo
   (synced to `templates/addons/<name>/` for publishing), copied through
   the same token rewriter as the base template.
3. **Anchored patches** — exact-string `anchor → replacement` edits on
   template-owned files. A missing anchor **fails the generation loudly**
   (file + anchor named) instead of producing a silently broken app;
   the per-backend e2e keeps anchors honest against template drift.

Generated-app tests stay backend-agnostic: the template's test helpers
pin `authRepositoryProvider` to the in-memory implementation (#34), so
every variant's suite runs green and offline.

## Alternatives considered

- **Full template variants per backend** — copies of `template/` would
  drift immediately; every template fix would need N-way porting.
- **Mason bricks** — mature templating, but adds a runtime dependency,
  replaces our working token-rewrite pipeline, and still needs per-brick
  maintenance; overkill for structured small diffs.
- **Runtime plugin architecture in the template** (backend chosen by
  config) — ships every SDK to every app, violating dependency-light.

## Consequences

- Template files carry implicit anchor contracts (e.g. the
  `WidgetsFlutterBinding.ensureInitialized();` line); editing them means
  updating addon patches — enforced by the addon e2e, and cheap to fix.
- One allowed wart: the provider-swap patch introduces a legal circular
  import between `auth_repository.dart` and the addon repository file.
- Each addon adds an e2e variant (~2 min CI); acceptable at 2-3 backends.
- Follow-up: `--backend firebase` (v0.5.0) reuses the mechanism as-is.
