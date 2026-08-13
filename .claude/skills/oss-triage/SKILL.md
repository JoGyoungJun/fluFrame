---
name: oss-triage
description: Maintain the fluFrame OSS community — triage GitHub issues/PRs, check CI health, track adoption metrics against the Claude for OSS program criteria, and propose next growth actions.
---

Community maintenance and adoption tracking for
https://github.com/JoGyoungJun/fluFrame. The long-term goal is meeting a
Claude for OSS eligibility track — see **CLAUDE.md "Project goal"** for the
full list and, more importantly, for which tracks are reachable here.

Short version, so this skill does not chase impossible numbers: dependent
repos and dependent packages are structurally **0** (a generated app carries
no `fluframe` manifest entry) and will stay 0 regardless of usage. The
realistic tracks are 200k+ monthly downloads, 20+ external contributors in
12 months, and the maintainer's own 100+ PRs merged into repos they do not
own — the last being entirely independent of this project.

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
   (`fluframe_app` / `FluFrame App` / `FluFrame 앱` / `FluFrame アプリ`),
   strings in all three ARBs (en + ja + ko), generated code
   regenerated, tests included, `.pubignore`
   patterns still slash-anchored.
4. **Adoption metrics**: WebFetch https://pub.dev/packages/fluframe —
   note version, pub points, downloads; record the numbers with today's
   date in the report so trends are visible across runs.
5. **Growth actions**: propose 1-3 concrete next steps sized to the
   current stage. Already done, so do not re-propose them: first release
   published, repo topics, README badges, live demo, example apps,
   Korean README, verified publisher. What remains is distribution a
   human has to do — posting to r/FlutterDev and the Korean channels, a
   Flutter Gems submission — plus good-first-issue labelling once there is
   traffic to convert.
   Be honest when the answer is "no engineering action will move this".

Drafts only — never post comments, close issues, or merge PRs without the
user approving each specific action.
