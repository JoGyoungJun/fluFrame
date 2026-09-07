/// Compile-time application configuration.
///
/// Values are injected at build time with
/// `--dart-define-from-file=env/dev.json` (or `env/prod.json`).
/// Defaults keep the app runnable with no flags at all.
///
/// **Not a secret store.** Every value below is a `String.fromEnvironment`
/// constant, which the compiler folds into the AOT snapshot or the JS
/// bundle: `strings` on any shipped APK, IPA or web build reads it back
/// out. Gitignoring `env/*.local.json` keeps a value out of git, not out
/// of the binary. So this holds client-public values — an analytics key,
/// a Sentry DSN, a Supabase publishable key — and never a credential a
/// server would authenticate with; that one belongs behind a backend the
/// app calls.
library;

import 'package:flutter/foundation.dart';

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

/// Whether a backend that was selected but never configured must refuse to
/// work rather than fall back to the in-memory fake.
///
/// The `--backend` addons keep a freshly generated app usable by falling
/// back to `InMemoryAuthRepository`, which accepts ANY email with a
/// six-character password. That is a convenience while the backend keys
/// are still empty — and an open front door the moment the same build is
/// shipped: a release built without `--dart-define-from-file` used to get
/// the fake with nothing on screen to say so.
///
/// Release mode is the obvious half. [isProdFlavor] is the other: a `prod`
/// flavor debug build is a staging build, and it must not authenticate
/// anyone either.
const bool failClosedWhenUnconfigured = kReleaseMode || isProdFlavor;
