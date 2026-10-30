plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
{{{smf_app_entry__gradle_app_plugins}}}
}

android {
    namespace = "{{android_namespace}}"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
{{{smf_app_entry__android_core_library_desugaring_enabled}}}
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "{{android_application_id}}"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "default"
    productFlavors {
        create("dev") {
            dimension = "default"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appName"] = "{{app_name.titleCase()}} Dev"
        }
        create("staging") {
            dimension = "default"
            applicationIdSuffix = ".staging"
            manifestPlaceholders["appName"] = "{{app_name.titleCase()}} Staging"
        }
        create("prod") {
            dimension = "default"
            manifestPlaceholders["appName"] = "{{app_name.titleCase()}}"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
{{{smf_app_entry__gradle_app_dependencies}}}
{{{smf_app_entry__android_core_library_desugaring_library}}}
}
