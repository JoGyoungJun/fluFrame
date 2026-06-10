# FulFrame Architecture

FulFrame uses explicit package and feature boundaries so app-foundation code can
be reused without locking an app into one backend, state-management package, or
product domain.

## Package Boundaries

| Package | Owns | May Depend On | Must Not Depend On |
|---------|------|---------------|--------------------|
| `fulframe_core` | Pure Dart contracts and framework primitives. | Dart SDK only, small pure Dart dependencies if needed later. | Flutter, platform plugins, backend SDKs, app features. |
| `fulframe_app` | Flutter app shell helpers, common state widgets, UI-facing conventions. | Flutter, `fulframe_core`. | App-specific features, backend SDKs in MVP. |
| `fulframe_testing` | Test fakes and harness helpers. | Dart or Flutter test tooling, `fulframe_core`. | Production-only adapters, external services. |
| `fulframe_lints` | Analyzer and lint defaults. | Analyzer configuration packages. | Runtime app code. |
| `examples/starter_app` | Runnable example app and sample features. | FulFrame packages, Flutter. | Private services or required credentials. |

`fulframe_core` is the lowest-level package. If a contract belongs there, it
must be useful without Flutter imports.

## Feature Folder Shape

Feature modules in apps should use this shape:

```text
lib/features/<feature_name>/
  domain/
  application/
  data/
  ui/
  platform/        # optional, only when OS/plugin adapters are needed
```

The starter app's task-list feature is the current reference implementation:

```text
examples/starter_app/lib/features/task_list/
  domain/task_item.dart
  domain/task_repository.dart
  application/task_list_view_model.dart
  data/in_memory_task_repository.dart
  ui/task_list_screen.dart
```

## Layer Responsibilities

| Layer | Owns | Can Import | Must Not Own |
|-------|------|------------|--------------|
| `domain` | Entities, value objects, repository contracts, domain rules. | `fulframe_core`, Dart SDK. | Flutter widgets, persistence details, network clients. |
| `application` | View models, use cases, commands, orchestration, UI-ready state. | `domain`, `fulframe_core`. | Raw platform APIs, widget layout, database clients. |
| `data` | Repository implementations, DTO mapping, local or remote adapters. | `domain`, `fulframe_core`, adapter dependencies. | Widget state, screen layout, product navigation. |
| `ui` | Screens, widgets, user input handling, display state binding. | `application`, `domain` types when needed, `fulframe_app`, Flutter. | Network calls, persistence, business rules. |
| `platform` | OS or plugin adapters. | `domain` contracts, platform plugins. | Product rules, widget layout. |

## Import Direction

Dependencies should point inward:

```text
ui -> application -> domain
data -> domain
platform -> domain
```

The domain layer should not import application, data, UI, or platform code. Data
and platform implementations satisfy domain contracts; application code
orchestrates those contracts; UI renders application state.

## State Management

The MVP does not require Riverpod, Provider, Bloc, or another global state
package. The default pattern is a simple view model contract that can later be
wrapped by an app's preferred state-management tool.

For example, the task-list screen owns a `TaskListViewModel` instance and reacts
to its notifications. That keeps the sample understandable while leaving room
for apps to replace the binding layer.

## Error, Result, And Config Boundaries

- Use `Result<TFailure, TValue>` for explicit success/failure handling in
  reusable logic.
- Use `AppException` for framework-level failures that need a stable code and
  message.
- Use `AppConfig` for environment-specific values without tying core code to a
  backend or remote config service.
- Use `Clock` and `AppLogger` contracts when logic needs deterministic tests.

## MVP Rules

- Keep `fulframe_core` pure Dart.
- Keep starter features runnable without external services.
- Add contracts before concrete integrations when an adapter might change.
- Prefer local or in-memory implementations in examples until the integration
  boundary is clear.
- Do not add a mandatory state-management or backend package in MVP.
- Tests should cover reusable contracts and visible starter-app behavior.
