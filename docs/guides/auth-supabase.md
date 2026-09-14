# Swapping the auth scaffold to Supabase

> **TIP**: new projects can skip this guide entirely — `fluframe create my_app --backend supabase` wires all of this automatically. This guide is for adding supabase to an app generated without it.

The template ships a backend-neutral auth flow behind one seam:
`AuthRepository` (`lib/features/auth/data/auth_repository.dart`). This
guide replaces the fake `InMemoryAuthRepository` with Supabase Auth.
Nothing in the UI, router, or controller changes.

Every step below produces the same code `--backend supabase` generates —
the source of truth is `packages/fluframe/lib/src/backends.dart` and
`template_addons/supabase/`, and the ordering comments there explain the
two things this guide used to get wrong.

> API names below match `supabase_flutter` v2 — double-check against the
> [package docs](https://pub.dev/packages/supabase_flutter) for your
> version.

## 1. Add the dependency

```sh
flutter pub add supabase_flutter:^2.17.1
```

Pin the major. The repository below uses `publishableKey:`, which 1.x does
not have, and an unconstrained `pub add` resolves to whatever is latest on
the day you run it — so the next major would break the app on its release
day. `--backend supabase` pins this exact constraint.

## 2. Put your project keys into the env files

Supabase needs a URL and an anon key — exactly what the template's
`--dart-define-from-file` flavors are for. Add to `env/dev.json` (and
`env/prod.json`). Both keys are client-public by design, which is what
makes this the right place for them: `--dart-define` values reach the
app as `String.fromEnvironment` constants and are compiled into the
binary, so nothing a server authenticates with belongs here — see
`template/README.md`. Keep per-developer values in `env/*.local.json`,
which is gitignored:

```json
{
  "APP_FLAVOR": "dev",
  "API_BASE_URL": "https://jsonplaceholder.typicode.com",
  "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "<publishable key>"
}
```

## 3. Implement the repository

`lib/features/auth/data/supabase_auth_repository.dart`:

```dart
import 'package:fluframe_app/core/storage/key_value_store.dart';
import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Whether this build was compiled with both Supabase keys.
///
/// Compile-time, so `main.dart` can decide whether to attempt
/// `Supabase.initialize` at all — which is why this is separate from
/// [SupabaseAuthRepository.isConfigured], the runtime answer that also
/// requires the initialize to have succeeded.
const bool supabaseKeysPresent =
    String.fromEnvironment('SUPABASE_URL') != '' &&
    String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY') != '';

/// Set by `main.dart` once `Supabase.initialize` returns without throwing.
///
/// Stands in for the `Firebase.apps.isNotEmpty` probe the Firebase addon
/// gets from its SDK; supabase_flutter has no readable equivalent.
bool supabaseInitialized = false;

/// The auth backend this build should use.
///
/// A freshly generated app has no Supabase project yet, and
/// `Supabase.initialize` with an empty URL throws before the first frame
/// — a black screen with nothing on it. Until both keys are set the app
/// keeps running on the in-memory fake, the same way the Sentry and
/// Amplitude addons stay inert without their keys.
///
/// That convenience is scoped to debug and profile builds of the `dev`
/// flavor. A release — or any `prod` build — that never received them
/// gets [UnconfiguredAuthRepository] instead: the fake signs in any email
/// with a six-character password, and shipping that as the login screen
/// is worse than shipping one that refuses everybody.
/// See `failClosedWhenUnconfigured` in `core/config/app_config.dart`.
AuthRepository supabaseAuthOrFallback(KeyValueStore store) =>
    SupabaseAuthRepository.isConfigured
    ? SupabaseAuthRepository()
    : unconfiguredBackendRepository('Supabase', store);

/// [AuthRepository] backed by Supabase Auth.
///
/// Configuration comes from `--dart-define-from-file` (see `env/*.json`:
/// SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY) via `Supabase.initialize` in
/// `main.dart`.
class SupabaseAuthRepository implements AuthRepository {
  /// Whether this build reached a Supabase project: it was given both
  /// keys, and `Supabase.initialize` then succeeded.
  ///
  /// Both halves are load-bearing, and neither is enough alone.
  ///
  /// Firebase gets the second half for free — `Firebase.apps.isNotEmpty`
  /// is false when `initializeApp` threw, so its fallback is correct
  /// without any extra state. Supabase exposes no equivalent probe:
  /// `Supabase.instance` throws rather than reporting, so a build whose
  /// `initialize` failed would otherwise still look configured here, be
  /// handed the real repository, and throw "not initialized" on every
  /// single auth call. [supabaseInitialized] closes that gap.
  ///
  /// The first half reads BOTH keys because the addon seeds both empty in
  /// `env/*.json`. Gating on the URL alone meant a half-filled env file
  /// flipped this to true, bypassed [unconfiguredBackendRepository] and
  /// its release-mode refusal, and produced a client that 401s on every
  /// request instead of an app that says it is not configured.
  static bool get isConfigured => supabaseKeysPresent && supabaseInitialized;

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  @override
  Future<User> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final signedInEmail = response.user?.email;
      if (signedInEmail == null) {
        throw const AuthException('Sign-in returned no user.');
      }
      return User(email: signedInEmail);
    } on supabase.AuthException catch (error) {
      // Map the SDK's exception onto the app's type so the UI never
      // depends on Supabase.
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supabase.AuthException catch (error) {
      // Mapped exactly as signIn maps it: AuthRepository.signOut
      // documents AuthException, and a bare `=> _client.auth.signOut()`
      // let the SDK's own type straight past that seam.
      throw AuthException(error.message);
    }
  }

  @override
  Future<User?> restoreSession() async {
    final email = _client.auth.currentSession?.user.email;
    return email == null ? null : User(email: email);
  }
}
```

`supabaseAuthOrFallback` is not optional decoration. Without it, an app
whose keys are not filled in yet gets a login screen that throws the
moment it is used.

## 4. Initialize in `main.dart`

Add the SDK import. Prefix it: `supabase_flutter` exports a `User`, and so
does the template's own auth domain, which `main.dart` names in its boot
state. Unprefixed, both are ambiguous and the app fails to analyze.

```dart
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
```

Then initialize **after** the two error hooks — not right after
`WidgetsFlutterBinding.ensureInitialized()`:

```diff
   FlutterError.onError = onFlutterError;
   WidgetsBinding.instance.platformDispatcher.onError = onPlatformError;
+
+  if (supabaseKeysPresent) {
+    try {
+      await supabase.Supabase.initialize(
+        url: const String.fromEnvironment('SUPABASE_URL'),
+        publishableKey: const String.fromEnvironment(
+          'SUPABASE_PUBLISHABLE_KEY',
+        ),
+      );
+      supabaseInitialized = true;
+    } on Object catch (error, stackTrace) {
+      onPlatformError(error, stackTrace);
+    }
+  }
```

The ordering is the whole point. An `initialize()` that throws before
those two hooks are installed escapes into the root zone, and since it
also runs before `runApp` there is no widget tree to render the failure
into — you get a black screen with the error reported nowhere. This is
why the addon anchors on `onPlatformError`, not on `ensureInitialized()`.

The `try` matters separately from the ordering, and the two are easy to
conflate. The key gate only covers an *empty* config; a wrong one — a
typo'd URL, a trailing space, anything `Uri.parse` rejects — throws here
in a build that passed the gate. Without the catch that is still a black
screen, just a rarer one.

And the catch is only half a fix on its own. `supabaseInitialized` is
what makes `isConfigured` false afterwards, so the app falls back instead
of handing out a `SupabaseAuthRepository` whose `_client` throws on every
call. Firebase needs no equivalent line because `Firebase.apps.isNotEmpty`
already answers that question; `supabase_flutter` exposes nothing that
does.

Finally, replace the session-restore call in `_restoreSession` — Supabase
persists sessions itself:

```diff
-    return await InMemoryAuthRepository(store).restoreSession();
+    return await supabaseAuthOrFallback(store).restoreSession();
```

## 5. Swap the provider — the only wiring change

In `auth_repository.dart`:

```diff
 final authRepositoryProvider = Provider<AuthRepository>(
-  (ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),
+  (ref) => supabaseAuthOrFallback(ref.watch(keyValueStoreProvider)),
 );
```

Everything else — login screen, profile tab, redirect gating, tests
against the interface — keeps working unchanged. Keep
`InMemoryAuthRepository` around: widget tests stay fast and offline by
overriding `authRepositoryProvider` with it.

## Optional: gate the whole app

The template gates only `/profile`. To require sign-in everywhere,
change the redirect in `lib/app/router/app_router.dart`:

```diff
-      if (!signedIn && location.startsWith('/profile')) {
+      if (!signedIn && location != '/login') {
```
