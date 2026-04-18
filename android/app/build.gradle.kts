import java.util.Properties
import groovy.json.JsonSlurper

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.homeguard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        val localPropertiesFile = rootProject.file("local.properties")
        val localProperties = Properties()
        if (localPropertiesFile.exists()) {
            localProperties.load(localPropertiesFile.inputStream())
        }

        val secretsFile = rootProject.file("../secrets.json")
        var mapsApiKey = ""
        if (secretsFile.exists()) {
            val json = JsonSlurper().parseText(secretsFile.readText())
            if (json is Map<*, *>) {
                mapsApiKey = json["MAPS_API_KEY"]?.toString() ?: ""
            }
        }
        
        if (mapsApiKey.isEmpty()) {
            mapsApiKey = localProperties.getProperty("maps.api.key") ?: ""
        }
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
        
        applicationId = "com.example.homeguard"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
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

dependencies {
    // Es una función, por eso lleva paréntesis
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Si necesitas la de kotlin (opcional si ya funciona)
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.0")
}

// Tarea para generar google-services.json desde .env automáticamente
tasks.register("generateGoogleServices") {
    val secretsFile = rootProject.file("../secrets.json")
    val templateFile = file("google-services.json.template")
    val outputFile = file("google-services.json")

    inputs.file(secretsFile)
    inputs.file(templateFile)
    outputs.file(outputFile)

    doLast {
        if (!secretsFile.exists()) {
            println("ALERTA: Archivo secrets.json no encontrado en la raíz.")
            return@doLast
        }
        val json = JsonSlurper().parseText(secretsFile.readText())
        var apiKey = ""
        if (json is Map<*, *>) {
            apiKey = json["FIREBASE_API_KEY_ANDROID"]?.toString() ?: ""
        }

        if (apiKey.isNotEmpty() && templateFile.exists()) {
            val content = templateFile.readText().replace("@@FIREBASE_API_KEY_ANDROID@@", apiKey)
            outputFile.writeText(content)
            println("INFO: google-services.json actualizado desde .env")
        }
    }
}

// Asegurar que la tarea corra antes de que el plugin de Google Services procese el archivo
tasks.matching { it.name.startsWith("process") && it.name.endsWith("GoogleServices") }.all {
    dependsOn("generateGoogleServices")
}

