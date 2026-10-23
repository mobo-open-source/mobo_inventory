import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {

    namespace = "com.cybrosys.mobo_inventory"
    compileSdk = flutter.compileSdkVersion
    // Explicit NDK version as requested
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.cybrosys.mobo_inventory"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Support for 16 KB page sizes
    // AGP 8.5.1+ automatically aligns uncompressed shared libraries to 16 KB boundaries
    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }

    // Only configure release signing when android/key.properties provides a
    // storeFile; without this guard a missing key.properties breaks every
    // build, debug included.
    val releaseStoreFile = keystoreProperties.getProperty("storeFile")

    signingConfigs {
        if (releaseStoreFile != null) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(releaseStoreFile)
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }
    buildTypes {
        release {
            // Release builds are signed only with the real upload key; without
            // android/key.properties they are left unsigned rather than
            // silently falling back to the debug key.
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }
}

flutter {
    source = "../.."
}
