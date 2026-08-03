---
name: release
description: Release the fluframe CLI to pub.dev — version bump, changelog, bundle sync, e2e gate, dry-run file-list verification, publish, git tag + push.
argument-hint: "<version, e.g. 0.2.0>"
---

Execute a pub.dev release of `packages/fluframe`. Follow every gate — a
published version can never be deleted (only retracted within 7 days).

## Steps

1. **Version bump** (argument = new semver version):
   - `packages/fluframe/pubspec.yaml` → `version:`
   - `packages/fluframe/lib/src/command_runner.dart` → `cliVersion`
   - `packages/fluframe/CHANGELOG.md` → new `## <version>` section
     summarizing user-visible changes since the last tag
     (`git log fluframe-v<prev>..HEAD --oneline`).
2. **Sync the bundle**: `cd packages/fluframe && dart run
   tool/sync_template.dart` (must run from the package root).
3. **E2E gate**: `dart test -t e2e` — it generates from the synced bundle
   and fails if the bundle is incomplete. Do not proceed on failure.
4. **Dry-run + file-list audit**: `dart pub publish --dry-run` and verify
   the file list includes ALL of:
   - `templates/app/lib/...`
   - `templates/app/test/...`  ← a missing test/ means a `.pubignore`
     pattern lost its leading slash (they MUST stay slash-anchored)
   - `templates/app/gitignore` (dot-less)
5. **Land the bump via PR** — main is protected (PR + green CI,
   admins included):
   ```sh
   git checkout -b release/fluframe-v<version>
   git add -A
   git commit -m "release(cli): fluframe v<version>"
   git push -u origin release/fluframe-v<version>
   gh pr create --fill
   gh pr merge --squash --auto --delete-branch   # merges when CI passes
   ```
   **Do not proceed until `gh pr view --json state` reports MERGED** —
   and never tag until every feature PR of the milestone is MERGED too
   (0.7.0 incident: tagging while a feature PR was still OPEN published
   a release without its feature). Stuck PR behind newer main →
   `gh pr update-branch <pr>`.
6. **Publish = push the tag** (automated via OIDC — see
   `.github/workflows/publish.yml`; requires the one-time pub.dev admin
   setup: Automated publishing → GitHub Actions → repository
   `JoGyoungJun/fluFrame`, tag pattern `fluframe-v{{version}}`):
   ```sh
   git checkout main && git pull
   git tag fluframe-v<version>
   git push origin fluframe-v<version>
   gh run watch $(gh run list --workflow publish.yml --limit 1 --json databaseId --jq '.[0].databaseId')
   ```
   The workflow re-runs every gate (tag↔pubspec match, unit, bundle
   sync, e2e, dry-run) before publishing; a red gate publishes nothing —
   fix, delete the tag (`git push origin :fluframe-v<version>`), re-tag.
   **pub.dev rate limit**: max 12 publishes per rolling 24h (server
   rejects the upload). If hit, the tag stays valid — re-run later with
   `gh run rerun <run-id>` once a slot frees; no re-tagging needed.
   Also: `gh run watch ... | tail` swallows the exit code — check the
   run's `conclusion` field, never a piped `$?`.
   Manual fallback (pub.dev outage, first-time setup):
   `packages\fluframe\tool\publish.bat` in a real terminal, or with
   `--yes` from the `!` shell.
   Verify afterwards: `https://pub.dev/api/packages/fluframe` shows the
   new version.
7. **Post-check**: WebFetch https://pub.dev/packages/fluframe — confirm the
   new version is live and note the pub points once analysis completes.
