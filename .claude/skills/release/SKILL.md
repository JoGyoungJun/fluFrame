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
5. **Publish**: `dart pub publish` is interactive (y/N prompt + first-time
   browser auth). Ask the user to run it themselves with the `!` prefix:
   `! cd C:/Users/safte/github/fluFrame/packages/fluframe && dart pub publish`
6. **Record the release**:
   ```sh
   git add -A
   git commit -m "release(cli): fluframe v<version>"
   git tag fluframe-v<version>
   git push origin main --tags
   ```
7. **Post-check**: WebFetch https://pub.dev/packages/fluframe — confirm the
   new version is live and note the pub points once analysis completes.
