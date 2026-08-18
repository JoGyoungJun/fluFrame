# Security Policy

fluFrame is a code generator. Its output becomes the source of other
people's applications, and the CLI is published to pub.dev, so a flaw here
can reach further than this repository. Reports are taken seriously.

## Supported versions

| Version | Supported |
|---|---|
| Latest `1.x` on [pub.dev](https://pub.dev/packages/fluframe) | ✅ |
| Anything older | ❌ — upgrade first (`dart pub global activate fluframe`) |

Only the newest published version receives fixes. A published pub.dev
version can never be deleted, only retracted within 7 days of publishing, so
where a fix is possible it ships as a new version rather than a replacement.

## Reporting a vulnerability

**Do not open a public issue.**

Use GitHub's private vulnerability reporting:
[**Report a vulnerability**](https://github.com/JoGyoungJun/fluFrame/security/advisories/new).
It is private between you and the maintainer until an advisory is published.

Helpful to include, in rough order of usefulness:

- what an attacker gains, and what they need in order to get it
- the fluframe version (`fluframe --version`) and how the app was generated
  (the flags, or the `.fluframe.json` in the generated project)
- a reproduction — a generated project, a diff, or the exact commands
- your view of the severity, and whether it is already public anywhere

## What to expect

This is a single-maintainer project, so the commitments here are ones that
can actually be met rather than aspirational ones:

| Stage | Target |
|---|---|
| Acknowledgement | within 5 days |
| Initial assessment (is it a vulnerability, and how bad) | within 14 days |
| Fix or a stated plan with dates | within 30 days of the assessment |

If a report goes unacknowledged past those windows, escalate by opening a
**non-descriptive** public issue asking the maintainer to check their
security advisories — do not include details.

Credit is given in the advisory and the changelog unless you ask otherwise.

## In scope

- The CLI (`packages/fluframe/`) — argument handling, archive extraction in
  `fluframe upgrade`, anything that writes outside the target directory
- The published bundle — anything that ships to pub.dev which should not,
  including credentials or files from a maintainer's working tree
- The template (`template/`) and addons (`template_addons/`) — patterns that
  are insecure by default in every generated app, since every user inherits
  them
- The release pipeline (`.github/workflows/publish.yml`) — anything that
  could get an unintended artifact published

## Out of scope

- Vulnerabilities in dependencies with no fluFrame-specific exposure —
  report those upstream (we will bump the pin once a fix exists)
- The sample API the template's posts feature calls
  (`jsonplaceholder.typicode.com`), a third-party demo service
- Findings that require the attacker to already control the developer's
  machine or the generated project's git history

## Hardening in place

In the CLI, since 1.6.0 — everything `fluframe upgrade` pulls off the
network ends up merged into your own source tree, so it is refused until
it is provably the archive pub.dev published:

- The download is checked against the `archive_sha256` pub.dev publishes
  beside the archive URL, **before** a byte of it is inflated. The gzip
  CRC32 is checked too, but it proves only that the bytes are consistent
  with themselves — anyone who rewrites them recomputes it for free.
- The archive must arrive over https, or over the plain-http registry you
  named yourself (a self-hosted mirror; the tests use a loopback server).
  pub.dev's archive URLs redirect, so the whole chain is walked hop by hop
  and each hop re-checked — a hop off https is refused, not followed.
- The gzip trailer's declared uncompressed length (RFC 1952 §2.3.1) is
  read against an 8 MB ceiling before decompression starts, so an archive
  that claims more than that is refused unread rather than inflated into
  memory and measured afterwards.
- Nothing out of a bundle is written outside the directory it belongs in.
  Tar member paths are resolved and required to stay inside the extraction
  directory; addon patch targets, which come out of the downloaded
  bundle's own `addons.json`, are refused when that registry is parsed and
  checked again against the project root before the file is touched.

In the repository and the release pipeline:

- Every GitHub Action in both workflows is pinned to a full commit SHA, not
  a mutable tag, with the version in a trailing comment.
- Both workflows default to `permissions: contents: read`; only the jobs
  that need more declare it, and only what they need.
- Publishing uses pub.dev automated publishing via OIDC — there are no
  long-lived pub.dev credentials in this repository or in CI.
- Every release gate (tag↔pubspec match, unit tests, bundle sync, e2e,
  dry-run) runs before the publish step, in the same job.
