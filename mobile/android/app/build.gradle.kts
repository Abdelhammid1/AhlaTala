import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release-signing credentials from android/key.properties (gitignored).
// If the file is missing, release builds fall back to debug signing — useful
// for CI or a fresh clone, but the resulting .aab can't be uploaded to Play.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) load(FileInputStream(file))
}

android {
    namespace = "ai.manasety.ahlatala"
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
        applicationId = "ai.manasety.ahlatala"
        // flutter_local_notifications needs at least API 21; Flutter's own default
        // is fine but we force a floor to be explicit.
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only register the release signing config when key.properties + the
        // keystore file are both present. Otherwise fall back to debug signing
        // below so `flutter run --release` still works on a fresh clone.
        if (keystoreProperties["storeFile"] != null) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Use the release signing config when we have one, else fall back
            // to debug so the build never fails on a fresh clone.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
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
