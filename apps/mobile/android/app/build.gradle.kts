plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "id.kelasxtra.bimbel_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.kelasxtra.bimbel"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Dua aplikasi terpisah: siswa & tutor. Id paket berbeda supaya bisa
    // dipasang berdampingan (dua ikon) dan nanti punya notifikasi/daftar
    // toko sendiri-sendiri.
    flavorDimensions += "peran"
    productFlavors {
        create("siswa") {
            dimension = "peran"
            applicationId = "id.kelasxtra.bimbel"
            resValue("string", "app_name", "Kelasxtra")
        }
        create("tutor") {
            dimension = "peran"
            applicationId = "id.kelasxtra.tutor"
            resValue("string", "app_name", "Kelasxtra Tutor")
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

flutter {
    source = "../.."
}
