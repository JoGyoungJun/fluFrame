# FulFrame Roadmap

Last updated: 2026-06-09

## Product Thesis

FulFrame is an open-source Flutter app framework that gives developers a
production-ready architecture baseline, example app, testing setup, and
contribution-friendly project structure.

The core thesis is that Flutter developers should not have to rebuild the same
app-foundation features for every app. FulFrame prebuilds those common features
once so new apps can start from a stable foundation.

## MVP

1. Scaffold the monorepo.
2. Implement `fulframe_core` contracts.
3. Implement `fulframe_app` starter shell.
4. Add `fulframe_testing` helpers.
5. Add lints, analyze, format, and test automation.
6. Write README and contribution docs.
7. Prepare Codex for OSS application materials.

See `docs/mvp-plan.md` for the scoped MVP definition, milestones, non-goals,
and next implementation stories.

## Post-MVP

1. Optional backend adapters.
2. Optional state-management adapters.
3. CLI scaffolding for new features.
4. Golden-test and accessibility-test helpers.
5. pub.dev publishing workflow.
6. Example apps for common domains.
7. Reusable app-foundation modules: settings, onboarding, analytics contracts,
   cache conventions, notification contracts, and auth shell contracts.

## Release Gates

| Gate | Required Evidence |
|------|-------------------|
| Internal MVP | Example app runs, tests pass, docs explain architecture. |
| Public Alpha | README, license, contributing docs, issue templates, CI pass. |
| Package Release | Package docs, API surface review, pub.dev dry run. |
| Codex for OSS Application | Public repo, clear README, OSS application notes, roadmap, first scaffold. |
