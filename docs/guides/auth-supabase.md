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

/// The auth backend this build should use.
///
/// A freshly generated app has no Supabase project yet, and
/// `Supabase.initialize` with an empty URL throws before the first frame
/// — a black screen with nothing on it. Until `SUPABASE_URL` is set the
/// app keeps running on the in-memory fake.
AuthRepository supabaseAuthOrFallback(KeyValueStore store) =>
    SupabaseAuthRepository.isConfigured
    ? SupabaseAuthRepository()
    : InMemoryAuthRepository(store);

/// [AuthRepository] backed by Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  /// Whether this build was given a Supabase project to talk to.
  static const bool isConfigured = String.fromEnvironment('SUPABASE_URL') != '';

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
      // Same reason as signIn: a caller that wants to tell one
      // sign-out failure from another needs the app's own type.
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
+  if (SupabaseAuthRepository.isConfigured) {
+    await supabase.Supabase.initialize(
+      url: const String.fromEnvironment('SUPABASE_URL'),
+      publishableKey: const String.fromEnvironment(
+        'SUPABASE_PUBLISHABLE_KEY',
+      ),
+    );
+  }
```

The ordering is the whole point. An `initialize()` that throws before
those two hooks are installed escapes into the root zone, and since it
also runs before `runApp` there is no widget tree to render the failure
into — you get a black screen with the error reported nowhere. This is
why the addon anchors on `onPlatformError`, not on `ensureInitialized()`.

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
