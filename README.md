# FulFrame

FulFrame is an open-source Flutter app framework for developers who do not want
to rebuild the same app foundation for every new project.

Most Flutter apps need the same baseline pieces: bootstrap, routing, theming,
localization, configuration, logging, error handling, testing, CI, feature
structure, and release hygiene. FulFrame packages those common app-foundation
concerns into a reusable framework and starter template so each app can focus on
product-specific features.

## Current Status

FulFrame is in early MVP development. The repository currently contains a
Flutter monorepo scaffold, core framework contracts, Flutter app-shell helpers,
test helpers, shared lint defaults, CI configuration, and a starter app with a
local-only task-list feature.

The project is licensed under the MIT License.

The project is not published to pub.dev yet. The current goal is to make the
repository useful as a readable GitHub template first, then decide package
publishing after the public alpha shape is stable.

## What Is Included

- `fulframe_core`: pure Dart contracts such as results, use cases,
  application exceptions, config, logging, and clocks.
- `fulframe_app`: Flutter-facing app shell helpers and common loading, empty,
  error, and retry state widgets.
- `fulframe_testing`: deterministic fakes and test helpers for framework and
  feature tests.
- `fulframe_lints`: shared analyzer defaults.
- `examples/starter_app`: a runnable Flutter example app with a local task-list
  feature.
- `.github/workflows/quality.yml`: CI for workspace analysis and tests.

## Repository Shape

```text
packages/
  fulframe_core/
  fulframe_app/
  fulframe_testing/
  fulframe_lints/
examples/
  starter_app/
docs/
production/
design/
tool/
```

## Starter Feature

The starter app includes a local-only task-list feature. It intentionally avoids
backend setup and persistence so contributors can inspect the architecture
without service credentials.

The feature demonstrates FulFrame's default module boundaries:

- `domain`: feature entities and repository contracts.
- `application`: view model and orchestration.
- `data`: in-memory repository implementation.
- `ui`: Flutter screen and widgets.

See [docs/feature-module-guide.md](docs/feature-module-guide.md) for the folder
shape and rules for adding a new feature module.

## Local Setup

Install Flutter, then run these commands from the repository root:

```powershell
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

The current local setup notes are in
[docs/flutter-setup.md](docs/flutter-setup.md). This workspace has been verified
with Flutter 3.44.1 stable and Dart 3.12.1.

## MVP Direction

The MVP is meant to prove one idea: a Flutter app team should be able to start
from a maintained app foundation instead of rebuilding the same architecture and
tooling for every app.

The near-term work is:

1. Finish open-source readiness docs.
2. Choose and add a license.
3. Push the first public commit.
4. Keep expanding the starter app only where it proves reusable app-foundation
   behavior.

See [docs/mvp-plan.md](docs/mvp-plan.md) and [docs/roadmap.md](docs/roadmap.md)
for the current plan.

## MVP Defaults

- State-management default: no mandatory package is used in the MVP so far.
- License: MIT.
- Publishing: GitHub template first is the current planning default.
- Platform target: web-first verification with mobile-compatible Flutter code is
  the current planning default.
