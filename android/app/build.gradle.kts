/*
 * Copyright (C) 2026 qumolangmo
 *
 * This file is part of Wecho.
 *
 * Wecho is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Wecho is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Wecho.  If not, see <https://www.gnu.org/licenses/>.
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

    // Custom task: copy TCC libs, headers and include files to assets directory
    tasks.register<Copy>("copyTccAssets") {
        from(file("../../native/tcc/libtcc.a"))
        from(file("../../native/tcc/libtcc1.a"))
        from(file("../../native/tcc/tcclib.h"))
        from(file("../../native/tcc/libtcc.h"))
        from(file("../../native/scripting/wecho_dsp_c_api.h"))
        from(file("../../native/tcc/include")) {
            into("include")
        }
        into(file("src/main/assets/tcc"))
    }

    tasks.configureEach {
        if (name.matches(Regex("merge.*Assets"))) {
            dependsOn("copyTccAssets")
        }
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
