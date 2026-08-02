---
name: oss-triage
description: Maintain the fluFrame OSS community — triage GitHub issues/PRs, check CI health, track adoption metrics against the Claude for OSS program criteria, and propose next growth actions.
---

Community maintenance and adoption tracking for
https://github.com/JoGyoungJun/fluFrame. The long-term goal is meeting a
Claude for OSS criterion: 200k+ monthly pub.dev downloads, OR 500+
dependent repositories, OR 20+ external contributors in 12 months.

## Steps

1. **Repo health** (`gh`):
   ```sh
   gh run list --limit 5                 # CI green?
   gh issue list --state open
   gh pr list --state open
   gh api repos/JoGyoungJun/fluFrame --jq '{stars:.stargazers_count, forks:.forks_count, watchers:.subscribers_count}'
   ```
2. **Issue triage**: classify each open issue (bug / feature / question /
   invalid), draft a response for each, and flag anything reproducing a
   real defect — offer to fix bugs immediately (bugs in a boilerplate
   compound into every generated app).
3. **PR review prep**: for each open PR, check the fluFrame invariants
   before anything else — CI green, rename tokens intact
   (`fluframe_app` / `FluFrame App` / `FluFrame 앱`), strings in BOTH
   ARBs, generated code regenerated, tests included, `.pubignore`
   patterns still slash-anchored.
4. **Adoption metrics**: WebFetch https://pub.dev/packages/fluframe —
   note version, pub points, downloads; record the numbers with today's
   date in the report so trends are visible across runs.
5. **Growth actions**: propose 1-3 concrete next steps sized to the
   current stage (e.g. publish first release, mark repo as a template
   repository + add topics, README badges, example app screenshots/GIF,
   announce on r/FlutterDev or Flutter community channels, good-first-issue
   labels to attract the 20-contributor path).

Drafts only — never post comments, close issues, or merge PRs without the
user approving each specific action.
