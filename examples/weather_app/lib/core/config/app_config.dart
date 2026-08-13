/// Compile-time application configuration.
///
/// Values are injected at build time with
/// `--dart-define-from-file=env/dev.json` (or `env/prod.json`).
/// Defaults keep the app runnable with no flags at all.
library;

/// The active build flavor (`dev`, `prod`, ...).
const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'dev',
);

/// Base URL for the REST API used by the data layer.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://jsonplaceholder.typicode.com',
);

/// Whether this build is the production flavor.
const bool isProdFlavor = appFlavor == 'prod';
