# 001 — Backend-neutral auth scaffold

> Historical record: written against fluframe v0.3.0; current behaviour is defined by the code and CHANGELOG.

- **Status**: APPROVED (stage 1 of the backend roadmap; stages 2-3 = opt-in
  Supabase/Firebase overlays, specified in ADR 0001)
- **Shipped in**: v0.3.0
- **Date**: 2026-08-03

## 1. Problem

Auth is the most-requested boilerplate capability, but baking in a
backend SDK violates fluFrame's dependency-light rule and breaks the
"generated app is green out of the box" guarantee (Firebase cannot even
be configured non-interactively). Template users currently get no auth
pattern at all: no session model, no login flow, no route gating —
the patterns people copy most.

## 2. Goals / Non-goals

**Goals**
- A complete, testable auth flow with **zero new dependencies**:
  interface → fake implementation → controller → login/profile UI →
  router gating with return-path.
- The exact seam (`AuthRepository`) a real backend plugs into, plus
  written guides for wiring Firebase and Supabase manually.
- Session persistence across restarts via the existing `KeyValueStore`.

**Non-goals**
- Shipping any backend SDK (stage 2+: `--backend supabase` overlay).
- Real credential verification, token refresh, biometrics, OAuth.
- Whole-app gating (demonstrated in the guide as a 3-line change; the
  template gates only the profile tab so the demo stays explorable).

## 3. Design

**Domain** (`features/auth/domain/`)
- `User` — freezed data class, `{required String email}` (no JSON;
  persistence stores the email string directly).
- `AuthException implements Exception` — `message`; thrown by
  repositories on failed sign-in.

**Data** (`features/auth/data/`)
- `abstract interface class AuthRepository`:
  `Future<User> signIn({required String email, required String password})`,
  `Future<void> signOut()`, `Future<User?> restoreSession()`.
- `InMemoryAuthRepository implements AuthRepository` — accepts any
  credentials whose password is ≥6 chars (shorter → `AuthException`, so
  the error path is real and testable); ~400ms simulated latency;
  persists `auth.session.email` via `KeyValueStore`.
- `authRepositoryProvider` — the single swap point for real backends.

**Presentation** (`features/auth/presentation/`)
- `initialUserProvider` (`Provider<User?>`, default null) — overridden in
  `main.dart` bootstrap from `restoreSession()`, same pattern as
  `initialThemeModeProvider` (no auth flash on startup).
- `AuthController extends Notifier<User?>` — `signIn` (rethrows
  `AuthException` for the form to render), `signOut`.
- `LoginScreen` — `Form` with email/password `TextFormField`s (validators:
  required + email shape; password required), local submitting state,
  error banner on `AuthException`, honors a `from` return-path.
- `ProfileScreen` — avatar initial, signed-in-as line, sign-out button.

**Router** (third `StatefulShellBranch` + gating)
- Branch 3: `/profile` → `ProfileScreen`; tab icon `person_outline`.
- `/login` on the root navigator (full-screen above the shell), builder
  reads `state.uri.queryParameters['from']`.
- `redirect`: signed-out + `/profile*` → `/login?from=<loc>`; signed-in +
  `/login` → `from ?? '/home'`.
- Reactivity: `refreshListenable: ref.watch(authControllerProvider.listenable)`
  — riverpod 3.4's `ValueListenable` interop (verified in the pinned
  package source), so redirects re-evaluate on auth changes without
  rebuilding the router.

  > **Superseded:** the shipped router uses a dedicated `_AuthRefreshNotifier`. Do not `ref.watch` inside `appRouterProvider` — it rebuilds the whole router and loses the navigation stack. See `template/lib/app/router/app_router.dart`.

## 4. l10n keys (en + ko — Japanese was added later, in v0.10.0)

`profileTab`, `profileTitle`, `profileSignedInAs`, `loginTitle`,
`emailLabel`, `passwordLabel`, `signInButton`, `signOutButton`,
`emailRequired`, `emailInvalid`, `passwordRequired`, `passwordTooShort`,
`loginFailedMessage`.

## 5. Test plan

- Unit: `InMemoryAuthRepository` (persist/restore/clear session, short
  password throws), `AuthController` (initial override, signIn success
  and failure, signOut clears state + storage).
- Widget: `LoginScreen` validation messages on empty/invalid submit.
- Integration (`app_test.dart`): profile tab while signed out redirects
  to login; signing in lands on profile; sign-out returns to login.

## 6. Acceptance criteria

- [ ] Signed-out user tapping the Profile tab lands on the login screen
      with the return path preserved; signing in (any email + password
      ≥6 chars) lands back on Profile showing the email.
- [ ] Session survives restart: relaunching the app (bootstrap override)
      restores the signed-in user without showing login.
- [ ] Sign-out returns to the login redirect and clears persistence.
- [ ] Password <6 chars surfaces the localized failure message; form
      validators catch empty/malformed input before the repository.
- [ ] All strings via l10n (en+ko), zero analyzer issues, template
      suite green; no new dependencies in pubspec.
- [ ] Guides exist for swapping in Firebase and Supabase, each showing
      the exact `authRepositoryProvider` override diff.

## 7. Open questions

None — stage 2 questions (overlay composition, `--backend` flag) are
deliberately deferred to the stage-2 ADR.
