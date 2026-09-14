# Signing a generated app for release

A generated app's `android/` and `ios/` directories come from
`flutter create`, unmodified — they are not part of fluFrame's overlay
(see `overlayEntries` in
`packages/fluframe/lib/src/project_generator.dart`). That is deliberate:
platform runners are Flutter's to own and regenerate. It also means your
app inherits Flutter's defaults for release signing, and one of them
needs your attention before you ship.

## What you have right now

`android/app/build.gradle.kts` ships this:

```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

That is what makes `flutter run --release` work on a fresh checkout, and
it is the right default for development. It is not shippable: Play
Console rejects a debug-signed bundle outright, so this fails loudly at
upload rather than quietly in the field. There is nothing to *fix* until
you are ready to publish — this guide is the checklist for that day.

The `applicationId` a few lines above it is the other one:

```kotlin
applicationId = "dev.fluframe.fluframe_app"
```

`fluframe create --org com.yourcompany` sets the org half, so that line
reads `com.yourcompany.your_app` in your project. Check it anyway — it is
permanent once an app is published, and it is the single value you cannot
change later.

## Android

**1. Create an upload keystore.** Keep it out of the repository.

```sh
keytool -genkey -v -keystore ~/upload-keystore.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

**2. Point Gradle at it** with `android/key.properties`, which is
already covered by the generated `.gitignore`:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=upload
storeFile=<absolute path to upload-keystore.jks>
```

**3. Read it in `android/app/build.gradle.kts`**, above the `android {`
block:

```kotlin
import java.util.Properties

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
```

**4. Replace the debug signing config:**

```kotlin
signingConfigs {
    create("release") {
        keyAlias = keystoreProperties["keyAlias"] as String?
        keyPassword = keystoreProperties["keyPassword"] as String?
        storeFile = (keystoreProperties["storeFile"] as String?)?.let(::file)
        storePassword = keystoreProperties["storePassword"] as String?
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

Guard it if your CI builds release without the keystore: fall back to the
debug config when `key.properties` is absent, so a contributor's build
still compiles.

**5. Build and check what you got:**

```sh
flutter build appbundle --release \
  --dart-define-from-file=env/prod.json
```

`--dart-define-from-file` is not optional for a release build of a
fluFrame app. The flavor, API base URL and any backend keys are
compile-time constants read through `String.fromEnvironment`, so a
release built without it gets empty values — and an unconfigured backend
in a release build refuses every sign-in by design
(`failClosedWhenUnconfigured` in `lib/core/config/app_config.dart`).

Flutter's canonical reference:
<https://docs.flutter.dev/deployment/android>.

## iOS

Signing is handled by Xcode and your Apple Developer account rather than
by a file in the repository:

1. Open `ios/Runner.xcworkspace`.
2. Under **Signing & Capabilities**, set your team and bundle identifier.
   The bundle identifier should match the `applicationId` above.
3. Archive with `flutter build ipa --release
   --dart-define-from-file=env/prod.json`, then distribute from Xcode's
   Organizer or with `xcrun altool`.

Flutter's reference: <https://docs.flutter.dev/deployment/ios>.

## What not to commit

The generated `.gitignore` covers `android/key.properties`,
`*.jks`/`*.keystore` and `env/*.local.json`, so following the steps above
does not put anything in git by accident. Two reminders anyway:

- **Never commit a keystore or its passwords.** An upload key cannot be
  rotated without Play App Signing enrollment, and a leaked one is a
  reset of your release identity.
- **`--dart-define` values are not secrets.** They are compiled into the
  binary and readable by anyone with the APK. Client-public keys
  (a Supabase publishable key, a Sentry DSN) belong there; anything a
  server authenticates with does not. `lib/core/config/app_config.dart`
  says so at the top of the file, and it is the rule that decides what
  may go in `env/*.json` at all.

## Desktop and web

`flutter build windows`, `macos`, `linux` and `web` need no signing to
run locally. Store distribution does — macOS notarization, Windows
Authenticode — and both are outside what a generated app can configure
for you. Flutter's per-platform deployment pages cover them.
