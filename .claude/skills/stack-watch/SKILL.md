---
name: stack-watch
description: Check the Flutter/Dart ecosystem for new releases and breaking changes relevant to fluFrame — compare pinned versions against pub.dev reality, refresh CLAUDE.md's post-cutoff notes, and recommend actions.
---

The whole stack moves faster than any LLM knowledge cutoff. This command
re-grounds the project in current reality. Run it monthly, or before any
significant work after a gap.

## Steps

1. **Current state**: read `template/pubspec.yaml`,
   `packages/fluframe/pubspec.yaml`, and `flutter --version`.
2. **Reality check** (WebFetch/WebSearch — never answer from memory):
   - Latest Flutter stable + its Dart version (flutter.dev release notes,
     `docs.flutter.dev/release/breaking-changes` for anything new).
   - pub.dev latest for: `flutter_riverpod`, `go_router`, `freezed` (+
     `freezed_annotation`, `json_serializable`, `build_runner`), `dio`,
     `shared_preferences`, `very_good_analysis`, `mocktail`, `args`,
     `path`, `io`, `intl`.
   - Anything relevant to the CLI's contract: changes to `flutter create`
     output (the overlay depends on it), `dart fix`, gen-l10n config, pub
     publishing rules.
3. **Gap report** — a table: package → pinned → latest → risk
   (patch/minor/major/breaking) → one-line note. Call out specifically:
   - whether the `freezed`↔`build_runner` analyzer conflict (reason for
     the `^2.15.1` pin) is resolved;
   - any Flutter deprecations that would make `flutter analyze` (infos
     fatal) go red in the template or in freshly generated apps.
4. **Refresh docs**: update the "Post-knowledge-cutoff API notes" section
   of `CLAUDE.md` with anything that changed (keep the verified-on date).
5. **Recommend**: nothing to do / run `/upgrade-deps` / urgent breakage.
   Do not perform upgrades here — that is `/upgrade-deps`'s job.
