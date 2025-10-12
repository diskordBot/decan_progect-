// android/app/build.gradle.kts
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.decanat_progect"
    compileSdk = 36
    ndkVersion = "29.0.14033849"

    defaultConfig {
        applicationId = "com.example.decanat_progect"
        minSdk = flutter.minSdkVersion
        targetSdk = 36

        versionCode = 7
        versionName = "1.2.4"

        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    // Подпись
    val keystoreProperties = Properties().apply {
        val f = rootProject.file("key.properties")
        if (f.exists()) load(f.inputStream())
    }

    signingConfigs {
        getByName("debug") { /* default */ }

        if (keystoreProperties.keys.containsAll(setOf("storeFile","storePassword","keyAlias","keyPassword"))) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            // 🔴 ВЫКЛЮЧЕНО, чтобы не ловить крэши от R8/ProGuard
            isMinifyEnabled = false
            isShrinkResources = false

            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // implementation("androidx.multidex:multidex:2.0.1") // при minSdk < 21
}
