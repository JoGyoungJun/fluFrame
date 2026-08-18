## What and why

<!--
What this changes, and what problem it solves. Link the issue it came
from: "Fixes #123" / "Refs #123".
-->

## Checklist

<!-- Full detail: CONTRIBUTING.md -->

- [ ] Ran the verification for what I touched — `flutter analyze` +
      `flutter test` under `template/`, `dart analyze --fatal-infos` +
      `dart test -x e2e` under `packages/fluframe/`
- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
      **with a scope**, e.g. `fix(cli): handle spaces in output path`
- [ ] Every document that points at something this PR moved or renamed —
      a file path, a command, a flag, a CI job name — is updated **in this
      same PR**
- [ ] New user-facing strings are in all three ARBs (`app_en.arb`,
      `app_ja.arb`, `app_ko.arb`); if a translation is missing, the key
      carries the English value and it is said above
