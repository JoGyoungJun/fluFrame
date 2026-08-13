---
name: upgrade-deps
description: Upgrade template + CLI dependencies (and optionally the Flutter SDK) safely — outdated report, breaking-change research for post-cutoff versions, regen, full verification, and a chore(deps) commit proposal.
argument-hint: "[major|minor]"
---

Upgrade fluFrame's dependencies without breaking the template or the CLI.

## Rules

- **Never trust training knowledge for version facts.** Every package here
  moves faster than LLM cutoffs. Verify versions on pub.dev and read
  changelogs (WebFetch) before touching a major version.
- **Known constraint**: `freezed` 3.2.x conflicts with `build_runner`
  >=2.15.2 (analyzer bounds) — that is why `build_runner: ^2.15.1` is
  pinned in `template/pubspec.yaml`. On every run, re-check whether a newer
  freezed lifts this; if yes, unpin and note it in the commit body.
- Riverpod majors: check whether `flutter_riverpod/misc.dart` types
  (`Override`, `FutureProviderFamily`) moved again, and whether
  `ProviderContainer.test` / `retry:` signatures changed.
- After upgrading, update the "Post-knowledge-cutoff API notes" section in
  `CLAUDE.md` if any verified fact changed.

## Steps

1. Report current state:
   ```sh
   flutter --version
   cd template && flutter pub outdated
   cd packages/fluframe && dart pub outdated
   ```
2. Scope from the argument: default = minor/patch only (`flutter pub
   upgrade` / `dart pub upgrade`); `major` = also raise pubspec constraints
   (`--major-versions`), one package at a time, researching breaking
   changes first.
3. A Flutter SDK upgrade (`flutter upgrade`) is a bigger decision — surface
   that a new stable exists and ask before running it. If upgraded, re-read
   what `flutter create` now generates (the CLI overlays onto it) and rerun
   the e2e.
4. Regenerate: `flutter gen-l10n` + `dart run build_runner build
   --delete-conflicting-outputs` in `template/`.
5. Also check `.github/workflows/ci.yml` action versions
   (actions/checkout, subosito/flutter-action, dart-lang/setup-dart) for
   deprecation warnings seen in recent CI runs (`gh run view`).
6. Run `/verify` (full, including e2e).
7. Propose a commit: `chore(deps): <summary>` listing every bump and any
   breaking-change adaptations; commit only after the user approves.
