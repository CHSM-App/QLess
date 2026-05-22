import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release-signing credentials from android/key.properties if present.
// The file is gitignored and must hold:
//   storeFile=keystore/qless-release.jks
//   storePassword=...
//   keyAlias=...
//   keyPassword=...
// Falls back to debug signing when the file is missing so contributors can
// still run `flutter run --release` locally without the prod keystore.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "vengurlatech.qless"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "vengurlatech.qless"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
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
            // Use the release signing config when key.properties is wired up.
            // Without it, falls back to debug — APK won't be uploadable to
            // Play but `flutter run --release` still works for devs.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8: shrink + obfuscate Java/Kotlin code and strip unused
            // resources. Cuts APK size meaningfully (often 30-50% on
            // Flutter apps) and makes reverse-engineering the native
            // layer harder. Dart code is already AOT-compiled to native
            // and is unaffected — this only touches the Android/plugin
            // bytecode and res/ assets.
            //
            // If a release build crashes with a ClassNotFound or
            // NoSuchMethod that the debug build doesn't, the offender is
            // missing a keep rule — add it to proguard-rules.pro.
            //
            // Mapping file lands at
            //   build/app/outputs/mapping/release/mapping.txt
            // Upload it to Play Console (or Crashlytics) after every
            // release so production stack traces stay readable.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
