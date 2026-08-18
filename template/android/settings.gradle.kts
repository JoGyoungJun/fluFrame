// These platform runners are NOT what `fluframe create` produces.
//
// They exist for the two paths that build `template/` itself: running it
// locally, and using this repository as a GitHub template to start from
// `template/` directly (documented in the repository's root README.md).
// A generated app never receives them — `overlayEntries`
// (packages/fluframe/lib/src/project_generator.dart) lists no platform
// directory, so `fluframe create` takes its android/ from
// `flutter create`, and `tool/sync_template.dart` copies only those same
// entries into the published bundle.
//
// No CI job compiles this directory either: `generated-android`
// (.github/workflows/ci.yml) and the four nightly platform jobs each
// generate an app first and build that output. The AGP and Kotlin pins
// below, and the Gradle pin in gradle/wrapper/gradle-wrapper.properties,
// therefore gate nothing and can rot without turning a job red. Kept,
// not deleted: the GitHub-template path needs them.

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}

include(":app")
