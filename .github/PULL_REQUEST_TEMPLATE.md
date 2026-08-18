## What and why

<!--
What this changes, and what problem it solves. Link the issue it came
from: "Fixes #123" / "Refs #123".
-->

## Checklist

<!-- Full detail: CONTRIBUTING.md -->

- [ ] Ran the verification for what I touched — under `template/`,
      `dart format --set-exit-if-changed lib test` + `flutter analyze` +
      `flutter test`; under `packages/fluframe/`,
      `dart format --set-exit-if-changed lib test tool` +
      `dart analyze --fatal-infos` + `dart test -x e2e`
- [ ] Touched `template_addons/`? Ran, from the repository root,
      `dart format --set-exit-if-changed template_addons` — it is gated
      by the template CI job, not by one named after addons
- [ ] Touched `template/lib` or `template/test`? Both examples are
      re-synced (`dart run tool/check_example_drift.dart` from
      `packages/fluframe`; `--fix` does most of it) and everything
      `build_runner` rewrote is committed — CI stages before it diffs,
      so a new generated file that is not `git add`ed fails there
- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
      **with a scope**, e.g. `fix(cli): handle spaces in output path`
- [ ] Every document that points at something this PR moved or renamed —
      a file path, a command, a flag, a CI job name — is updated **in this
      same PR**
- [ ] New user-facing strings are in all three ARBs (`app_en.arb`,
      `app_ja.arb`, `app_ko.arb`); if a translation is missing, the key
      carries the English value and it is said above
