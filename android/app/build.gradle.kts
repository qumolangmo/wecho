/**
 * Copyright (c) 2026 qumolangmo
 * 
 * License: MIT License with Commons Clause License Condition v1.0
 * see LICENSE-MIT and LICENSE-COMMONS-CLAUSE in the project root for full license text.
 * 
 * For commercial use, please contact: qumolangmo@gmail.com
 */

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.qumolangmo.wecho"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    dependencies {
        implementation("com.google.oboe:oboe:1.10.0")
        implementation("dev.rikka.shizuku:api:13.1.5")
        implementation("dev.rikka.shizuku:provider:13.1.5")

    }

    defaultConfig {
        applicationId = "com.qumolangmo.wecho"
        minSdk = 29
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        externalNativeBuild {
            cmake {
                arguments("-DANDROID_STL=c++_shared")
            }
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // sence fluuter 3.35, the build.gradle.kts will be changed by flutter gradle plugin.
            // so we need to set the abiFilters manually.
            ndk.abiFilters.clear()
            ndk.abiFilters.addAll(listOf("arm64-v8a"))

        }

        debug {
            // Signing with the debug keys for now, so `flutter run --release` works.
            // signingConfig = signingConfigs.getByName("debug")

            // sence fluuter 3.35, the build.gradle.kts will be changed by flutter gradle plugin.
            // so we need to set the abiFilters manually.
            ndk.abiFilters.clear()
            ndk.abiFilters.addAll(listOf("arm64-v8a"))
        }
    }

    buildFeatures {
        prefab = true
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
}

flutter {
    source = "../.."
}
