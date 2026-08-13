# 0001 — Backend addons as anchored patch overlays

- **Status**: Accepted (amended 2026-08-06 — see *Amendment: what the
  addon mechanism owes downstream*)
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

## Amendment: what the addon mechanism owes downstream (2026-08-06)

Two things the original decision got wrong, both found by auditing 1.1.0.

**Dependencies are pinned to a major.** Point 1 above claimed "no pins to
maintain" as a benefit. It is a liability: `pub add amplitude_flutter`
resolves to whatever is latest *at generation time*, while the source we
inject is written against one major (`Amplitude(Configuration(...))`,
which 3.x did not have and a 5.x may not keep). Unpinned, an upstream
major release breaks every newly generated app on its release day, with
no fluframe change to point at. Dependencies now carry `^major.minor`
constraints, and a unit test fails if any addon declares one without.
The maintenance cost this ADR wanted to avoid is real, and belongs to
`/stack-watch` and `/upgrade-deps`.

**Anchors are an upgrade contract, not just a generation contract.**
The Consequences section says editing an anchored template line "means
updating addon patches — enforced by the addon e2e". The e2e only covers
`create`. `fluframe upgrade` also replays addon patches, against the
bundle of the version an app was *generated* with — so updating an anchor
to match today's template made it unfindable in every archived bundle,
and the upgrade aborted at exit 70 for every app that used any addon.
Two changes fix the class:

- Each published bundle ships `templates/addons.json`, the serialized
  addon definitions of its own release, and the upgrader prefers those
  when rebuilding that era's merge base.
- When the addons cannot be replayed anyway — a pre-1.2 bundle with no
  registry, or an addon since dropped from the CLI — the upgrader
  rebuilds *both* sides without addons and says so, rather than
  refusing. Files the addons touch then surface as conflicts, which a
  user can resolve.

**Addons degrade instead of failing at startup.** `--backend firebase`
put `Firebase.initializeApp` before `runApp` with a placeholder that
throws until `flutterfire configure` runs, so the first launch of every
generated app was a black screen — no widget tree, so not even a red
error screen. Auth addons now behave like the observability ones:
unconfigured means the app runs on the in-memory fake and reports why,
not that it fails to start.
