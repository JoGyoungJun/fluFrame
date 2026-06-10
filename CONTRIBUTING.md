# Contributing To FulFrame

FulFrame is an early-stage Flutter app framework. Contributions should keep the
project focused on reusable app-foundation behavior rather than product-specific
features.

## Local Setup

From the repository root:

```powershell
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

Flutter setup notes are in `docs/flutter-setup.md`.

## Production Workflow

FulFrame uses a file-backed planning workflow:

1. Update or create a GDD in `design/gdd/`.
2. Convert approved GDD scope into an epic under `production/epics/<layer>/`.
3. Break the epic into focused story files.
4. Implement one story at a time.
5. Record verification evidence in the story and
   `production/session-state/active.md`.

Do not implement broad features directly from an issue or conversation without a
story. Small documentation fixes may link directly to the relevant doc.

## Architecture Expectations

Feature modules should follow the starter app shape:

```text
lib/features/<feature_name>/
  domain/
  application/
  data/
  ui/
```

Rules:

- Keep domain code free of Flutter imports.
- Prefer contracts before concrete integrations.
- Avoid mandatory backend, auth, or state-management dependencies in MVP work.
- Keep starter features runnable without external services.
- Add tests for visible behavior or reusable contracts.

See `docs/feature-module-guide.md` for more detail.

## Pull Requests

Before opening a pull request:

- Run `dart run melos run analyze`.
- Run `dart run melos run test` when code or behavior changed.
- Update the active story with changed files and verification evidence.
- Keep unrelated refactors out of the PR.
- Link the relevant GDD, epic, story, or issue.

## License

By contributing, you agree that your contribution will be licensed under the
MIT License in `LICENSE`.
