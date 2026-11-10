plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    // El plugin de Flutter va después de los de Android y Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Mismo identificador que la app del teléfono: así comparte la configuración de
    // Firebase (google-services.json) y Google Play la publica como su versión para reloj.
    // Si cambias el applicationId del teléfono, cámbialo aquí también.
    namespace = "com.example.homeguard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.example.homeguard"
        minSdk = 30 // Wear OS 3 o superior (Galaxy Watch 4+, Pixel Watch)
        targetSdk = flutter.targetSdkVersion
        // Código de versión distinto del teléfono: Google Play exige que no se repita.
        versionCode = 1_000_000 + flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Igual que el teléfono: reemplazar por tu propia firma antes de publicar.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
