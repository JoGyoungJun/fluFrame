# Changelog

## 0.1.0

- Initial release.
- `fluframe create <name>` scaffolds a production-ready Flutter app:
  - Riverpod 3 (manual notifiers), go_router `StatefulShellRoute` tabs
  - freezed 3 + json_serializable models, dio with typed error mapping
  - Localization (en/ko) via `flutter gen-l10n`, Material 3 light/dark themes
  - Persisted settings (`SharedPreferencesAsync` behind a `KeyValueStore`)
  - `--dart-define-from-file` flavors, very_good_analysis, unit + widget tests
- Options: `--org`, `--description`, `--output-directory`, `--platforms`,
  `--no-pub`.
