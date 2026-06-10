# Feature Module Guide

FulFrame starter features are organized by responsibility so contributors can
copy the shape into real apps without adopting a backend or extra state package.

## Folder Shape

```text
lib/features/<feature_name>/
  domain/
  application/
  data/
  ui/
```

## Layers

| Layer | Purpose | Example |
|-------|---------|---------|
| `domain` | Entities and contracts that describe the feature. | `TaskItem`, `TaskRepository` |
| `application` | View models, use cases, and orchestration. | `TaskListViewModel` |
| `data` | Concrete repositories and adapters. | `InMemoryTaskRepository` |
| `ui` | Screens and widgets. | `TaskListScreen` |

## MVP Example

The starter app includes a local-only task-list feature. It has no backend and
no persistence; that is intentional. The feature exists to demonstrate:

- how a UI screen depends on an application view model;
- how the view model depends on a repository contract;
- how data implementation can be swapped later;
- how `fulframe_app` empty/error/loading states are used;
- how `fulframe_core` contracts keep feature logic framework-independent.

## Rules

- Keep domain code free of Flutter imports.
- Put Flutter-specific state and widgets in `application` or `ui`.
- Prefer repository contracts before concrete integrations.
- Start with local/in-memory implementations before adding external services.
- Add tests for each feature's visible behavior.
