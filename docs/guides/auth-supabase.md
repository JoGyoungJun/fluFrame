# Swapping the auth scaffold to Supabase

> **TIP**: new projects can skip this guide entirely — `fluframe create my_app --backend supabase` wires all of this automatically. This guide is for adding supabase to an app generated without it.

The template ships a backend-neutral auth flow behind one seam:
`AuthRepository` (`lib/features/auth/data/auth_repository.dart`). This
guide replaces the fake `InMemoryAuthRepository` with Supabase Auth.
Nothing in the UI, router, or controller changes.

> API names below match `supabase_flutter` v2 — double-check against the
> [package docs](https://pub.dev/packages/supabase_flutter) for your
> version.

## 1. Add the dependency

```sh
flutter pub add supabase_flutter
```

## 2. Put your project keys into the env files

Supabase needs a URL and an anon key — exactly what the template's
`--dart-define-from-file` flavors are for. Add to `env/dev.json` (and
`env/prod.json`; real secrets belong in `env/*.local.json`, which is
gitignored):

```json
{
  "APP_FLAVOR": "dev",
  "API_BASE_URL": "https://jsonplaceholder.typicode.com",
  "SUPABASE_URL": "https://<project>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "<publishable key>"
}
```

## 3. Initialize in `main.dart`

```dart
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  publishableKey: const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
);
```

Place it right after `WidgetsFlutterBinding.ensureInitialized()`. Then
replace the session-restore line — Supabase persists sessions itself, so
drop the `InMemoryAuthRepository(store).restoreSession()` call and use
`SupabaseAuthRepository().restoreSession()` (below) instead.

## 4. Implement the repository

`lib/features/auth/data/supabase_auth_repository.dart`:

```dart
import 'package:fluframe_app/features/auth/data/auth_repository.dart';
import 'package:fluframe_app/features/auth/domain/auth_exception.dart';
import 'package:fluframe_app/features/auth/domain/user.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// [AuthRepository] backed by Supabase Auth.
class SupabaseAuthRepository implements AuthRepository {
  supabase.GoTrueClient get _auth => supabase.Supabase.instance.client.auth;

  @override
  Future<User> signIn({required String email, required String password}) async {
    try {
      final response =
          await _auth.signInWithPassword(email: email, password: password);
      final sessionUser = response.user;
      if (sessionUser?.email == null) {
        throw const AuthException('Sign-in returned no user.');
      }
      return User(email: sessionUser!.email!);
    } on supabase.AuthException catch (error) {
      // Map the SDK's exception onto the template's type so the UI
      // never depends on Supabase.
      throw AuthException(error.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<User?> restoreSession() async {
    final email = _auth.currentSession?.user.email;
    return email == null ? null : User(email: email);
  }
}
```

## 5. Swap the provider — the only wiring change

In `auth_repository.dart` (or wherever you prefer):

```diff
 final authRepositoryProvider = Provider<AuthRepository>(
-  (ref) => InMemoryAuthRepository(ref.watch(keyValueStoreProvider)),
+  (ref) => SupabaseAuthRepository(),
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
