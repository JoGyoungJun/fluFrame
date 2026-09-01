# Versioning & stability policy

From **1.0.0**, fluframe follows [semantic versioning](https://semver.org)
against the public contract defined below. If something here breaks in a
minor or patch release, that is a bug — please file it.

## The public contract

1. **CLI surface** — commands (`create`, `add feature`, `doctor`,
   `upgrade`) and their documented options. Flags may gain values (new
   backends/addons) in minors; renaming or removing one is a major.
2. **Generation guarantees** — a freshly generated app (any addon combo)
   passes `flutter analyze` with zero issues and its full test suite,
   on the stable Flutter release current at publish time.
3. **Rename tokens** — `fluframe_app`, `FluFrame App`, `FluFrame 앱`,
   `FluFrame アプリ` and their rewrite semantics.
4. **Generation metadata** — `.fluframe.json` with `"schema": 1`.
   Additive fields are minors; a schema bump is a major and `upgrade`
   will keep reading all older schemas.
5. **Addon mechanism** (ADR 0001) — `--backend`, `--error-reporting`,
   `--analytics` stay stackable; new addon values are minors.
6. **Upgrade path** (ADR 0002) — every published version's template
   bundle remains inside its pub.dev archive forever, so
   `fluframe upgrade` can reconstruct any published base. Skipped
   version numbers are never published and therefore never valid bases.
7. **Input-domain narrowing** — refusing an argument value that was
   previously accepted is a **minor** when the refused value could not
   have produced a correct result (it corrupted state, escaped the
   project tree, or silently did something other than what it named),
   and a **major** otherwise. Precedents: the three 1.7.0 `upgrade`
   refusals (hand-carried `.fluframe.json` values that redirected the
   merge base), and the `create` output-path metacharacter refusal
   (a path cmd.exe splits into two commands before Flutter sees it).
   Such a narrowing must be named in the CHANGELOG entry it ships in.

## What is NOT covered

Template internals may evolve freely between versions — that is the
point of `upgrade`. Undocumented flags, the repo's own tooling
(`tool/`, CI), and example apps carry no compatibility promise.

## Deprecation policy

Deprecated CLI options keep working for at least one minor release,
emitting a warning that names the replacement, before removal in the
next major.

## Release cadence note

pub.dev limits publishes to 12 per rolling 24h — release batching is
deliberate, and consolidated versions (e.g. work labeled 0.13/0.14
internally shipping inside 1.0.0) are normal: a version number only
exists once it is published.

**When a release is cut**: a release is cut when an improvement cycle's
PR lands on `main`, or sooner when `main` carries a user-facing fix a
current user is waiting on. The maintainer decides; the decision and its
version classification are recorded in the cycle report's verdict, and
the mechanics live in CONTRIBUTING's "Releasing (maintainers)" section.
`main` should not sit more than one cycle ahead of the last published
version without either a release or a recorded reason.
