# macOS runner — not what `fluframe create` produces

This directory exists for the two paths that build `template/` itself:
running it locally, and using this repository as a GitHub template to
start from `template/` directly (documented in the repository's root
README.md).

A generated app never receives these files. `overlayEntries`
(`packages/fluframe/lib/src/project_generator.dart`) lists no platform
directory, so `fluframe create` takes its `macos/` from `flutter create`,
and `tool/sync_template.dart` copies only those same entries into the
published bundle.

No CI job compiles this directory either. The nightly
`Generated app — macOS desktop build` (`.github/workflows/nightly.yml`),
like every other platform job, generates an app first and builds that
output. The Xcode project settings, the `Runner/Configs/*.xcconfig`
values and the entitlements here therefore gate nothing and can rot
without turning a job red — they are exercised only by whoever builds
`template/` by hand. Kept rather than deleted because the GitHub-template
path needs them.

## Why this note is a README

Every checked-in file here is owned by a tool that rewrites it:
`Runner.xcodeproj/project.pbxproj`, the `.xcworkspace` data and the
shared scheme are rewritten whenever Xcode saves,
`Flutter/GeneratedPluginRegistrant.swift` and `Runner/Configs/*.xcconfig`
belong to the Flutter tool, and Xcode's plist editor drops XML comments
out of `Info.plist`. A `Podfile` would be the conventional home for a
note like this, but this directory has none, and adding one would not be
inert: the Flutter tool takes the presence of `macos/Podfile` as the
signal to run CocoaPods, so a comment-only Podfile would break the very
build path this note exists to protect. GitHub renders this file
directly under the directory listing, which is where someone arriving by
the GitHub-template path is already looking.
