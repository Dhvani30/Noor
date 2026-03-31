plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.noor_new"
    compileSdk = 36 // The stable bridge version we discussed
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ FIXED: Added 'is' and '=' for Kotlin DSL
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // ✅ FIXED: Added '='
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.noor_new"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Add your Mapbox token here if needed
        manifestPlaceholders["MAPBOX_ACCESS_TOKEN"] = "pk.eyJ1IjoiZGh2YW5pLTMwIiwiYSI6ImNtbmRoNmh4ajAxd2EycXF2MXVkaWxpODAifQ.fAYb1geyZFyn6zyxv631-A"
    }
}

dependencies {
    // ✅ FIXED: Added parentheses () around the string
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}