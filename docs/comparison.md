# fluFrame vs. the alternatives

You do not need another Flutter starter. You need the right one, and for a
lot of projects that is not fluFrame. This page is meant to help you decide
against it quickly if it is a bad fit.

> **Facts checked 2026-08-08** against `flutter create` on Flutter 3.44,
> and against the [very_good_core 1.5.0 brick source][vgc-brick] and the
> [Very Good CLI docs][vgv-docs]. Where this page states what another tool
> does, it is quoting that tool's own current sources — not our memory of
> them. If you find a claim that has gone stale,
> [open an issue](https://github.com/JoGyoungJun/fluFrame/issues/new) and
> it will be corrected.

## The short version

| | Best when |
|---|---|
| **`flutter create`** | You want to own every decision, or you are learning. |
| **[Very Good CLI][vgv-docs]** | Your team writes Bloc, or you need something that is not an app (package, plugin, game, docs site). |
| **Clone a boilerplate repo** | You want a starting point and never want an upstream again. |
| **fluFrame** | You want an app that is already wired end to end **and** you want to keep receiving template improvements after generating it. |

## The one thing that is actually different

Every starter is a snapshot. You run it, you get files, and from that
moment the starter and your app diverge forever — when the template fixes a
bug or adopts a new SDK idiom, your app does not hear about it. Backporting
is a manual diff against a repo you no longer have a relationship with.

fluFrame is the only Flutter starter we know of that keeps that
relationship:

```sh
fluframe upgrade            # dry run by default: shows what would change
fluframe upgrade --apply    # three-way merge into your app
```

It reconstructs the template as it was at *your* generation version from
the published pub.dev archive, diffs it against the current template, and
merges the result into your working tree with `git merge-file` — the same
three-way merge git itself uses. Your edits survive; genuine conflicts are
reported as conflicts rather than silently resolved. The mechanism is
recorded in [ADR 0002](adr/0002-upgrade-three-way-merge.md).

That is the reason to pick fluFrame. If it does not matter to you, the
rest of this page probably points somewhere else.

## Side by side

What a generated app contains on day one:

| | `flutter create` | Very Good CLI (`very_good_core`) | fluFrame |
|---|---|---|---|
| Sample app | Counter | Counter | Counter, REST list/detail, settings, login |
| State management | `setState` | `bloc` + `flutter_bloc` | `flutter_riverpod` 3 (manual notifiers, no codegen) |
| Routing | none chosen | none chosen | `go_router` 17, `StatefulShellRoute` tabs, nested routes |
| HTTP client | none | none | `dio`, `DioException` mapped to a sealed `ApiException` |
| Persistence | none | none | `KeyValueStore` over `SharedPreferencesAsync` |
| Models | none | none | `freezed` 3 + `json_serializable` |
| Auth | none | none | Backend-neutral scaffold: login, gated routes, persisted session |
| Localization | none | `flutter_localizations` + `intl` | `flutter_localizations` + `intl`, 3 locales shipped (en, ja, ko) |
| Theming | default | default | Material 3 from a seed color, 6 presets, light/dark/system, persisted |
| Flavors | none | 3 (development, staging, production) | 2 (`env/dev.json`, `env/prod.json`) via `--dart-define-from-file` |
| Lints | `flutter_lints` | `very_good_analysis` | `very_good_analysis` |
| Tests out of the box | 1 widget test | Unit + widget, **100% line coverage** | Unit + widget (template measures ~81%) |
| CI for your app | none | GitHub Actions | GitHub Actions |
| Crash-reporting seam | none | `bootstrap.dart` captures exceptions | Error seam + optional `--error-reporting sentry` |
| Analytics seam | none | none | Backend-neutral seam with automatic screen tracking, optional `--analytics amplitude` |
| Backend wiring | none | none | Optional `--backend supabase` / `--backend firebase` overlays |
| **Updates after generation** | **none** | **none** | **`fluframe upgrade`** |

Two rows deserve a footnote rather than a checkmark:

- **Very Good CLI's 100% coverage is real and fluFrame's is not.** Their
  generated app is a counter, so covering all of it is achievable and they
  hold that line. fluFrame's template covers networking, persistence, auth,
  routing and theming, and sits in the low 80s with a CI floor at 78%. More
  surface, less proportional coverage — pick whichever of those you value.
- **Very Good CLI generates nine kinds of project**, not one:
  app, app UI, Dart CLI, Dart package, docs site, Flame game, Flutter
  package, Flutter plugin, Wear OS app. fluFrame generates apps. If you
  maintain a package or a plugin, fluFrame has nothing for you.

## Do not pick fluFrame if…

- **Your team writes Bloc.** fluFrame is Riverpod, deliberately and
  throughout — controllers, tests, docs and the upgrade merge all assume
  it. There is no Bloc variant and none is planned. Very Good CLI ships
  Bloc with `bloc_test`, `bloc_lint` and `bloc_tools` already wired; that
  is a better day and a better year.
- **You need to generate something other than an app.** See above.
- **You want the established option.** Very Good CLI is maintained by an
  agency that uses it on client work and has years of adoption behind it.
  fluFrame is new and its adoption numbers are small; that is a real
  reason to prefer the incumbent, and pretending otherwise would not help
  you.
- **You want zero upstream.** If the appeal of a boilerplate is that it is
  *yours* the moment it lands, `fluframe upgrade` is a feature you will
  never run, and a plain `git clone` of any template you like the look of
  costs you nothing.
- **You disagree with the stack.** go_router, dio, freezed and
  `SharedPreferencesAsync` are choices, not laws. Replacing one is a
  normal afternoon, but replacing three means you wanted a different
  starter.

## Pick fluFrame if…

- You want to `flutter run` a real app — routed, themed, localized,
  talking to an API, with a login flow and tests — within a minute of
  installing the CLI, and then delete the parts you do not want.
- You expect the project to outlive the day you generated it, and you want
  template fixes and SDK-idiom updates to reach it without you diffing
  anything by hand.
- Riverpod, go_router and freezed are already what you would have chosen.
- You want an escape hatch for the backend decision: start on the
  dependency-free auth scaffold, add `--backend supabase` or
  `--backend firebase` when you know.

## Try it before you decide

- **[Live demo](https://jogyoungjun.github.io/fluFrame/)** — a generated
  app, unmodified, running in your browser.
- `fluframe create scratch_app && cd scratch_app && flutter test` — about
  a minute, and you can delete the directory afterwards.

[vgc-brick]: https://github.com/VeryGoodOpenSource/very_good_templates/tree/main/very_good_core
[vgv-docs]: https://cli.vgv.dev/docs/templates/core
