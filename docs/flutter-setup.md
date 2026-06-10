# Flutter Setup

Flutter SDK is installed at:

```text
C:\Users\safte\flutter
```

The user PATH includes:

```text
C:\Users\safte\flutter\bin
```

Open a new terminal after installation so PowerShell picks up the updated PATH.

Installed versions:

- Flutter 3.44.1 stable
- Dart 3.12.1

## Required Local Setup

From the repository root, run:

```powershell
dart pub get
dart run melos bootstrap
dart run melos run analyze
dart run melos run test
```

These commands passed on 2026-06-09 when run with
`C:\Users\safte\flutter\bin` prepended to PATH.

## Package-Level Checks

Core package:

```powershell
Set-Location packages/fulframe_core
dart pub get
dart test
```

Flutter packages:

```powershell
Set-Location packages/fulframe_app
flutter pub get

Set-Location ../../examples/starter_app
flutter pub get
flutter test
```

## Remaining Doctor Items

`flutter doctor -v` reports Flutter itself, Chrome, connected devices, network
resources, and Windows version as OK.

Remaining environment items:

- Android SDK cmdline-tools are missing.
- Android licenses have not been accepted.
- Visual Studio is missing C++ desktop development components needed for native
  Windows desktop builds.

These are not required for current package analysis and starter app widget tests,
but they are required before Android or native Windows app builds.
