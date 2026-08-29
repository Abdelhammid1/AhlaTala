plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "sa.ahlatolla.ahla_tolla"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications on older API levels — enables
        // Java 8+ date/time APIs (java.time.*) to be back-compiled for min SDK.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "sa.ahlatolla.ahla_tolla"
        // flutter_local_notifications needs at least API 21; Flutter's own default
        // is fine but we force a floor to be explicit.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Debug signing so `flutter run --release` works out of the box.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Companion to isCoreLibraryDesugaringEnabled above. Kept minor-version-loose
    // so a future Android Gradle Plugin upgrade doesn't pin us.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
