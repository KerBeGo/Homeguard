import java.util.Properties

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

    // Remove kotlinOptions from here

    defaultConfig {
        // ...
        // Leer llaves desde local.properties y también desde .env
        val localPropertiesFile = rootProject.file("local.properties")
        val localProperties = Properties()
        if (localPropertiesFile.exists()) {
            localProperties.load(localPropertiesFile.inputStream())
        }

        // Leer desde .env en la raíz del proyecto
        val envFile = rootProject.file("../.env")
        val envProperties = Properties()
        if (envFile.exists()) {
            envFile.inputStream().use { envProperties.load(it) }
        }

        // Prioridad: .env -> local.properties
        val mapsApiKey = envProperties.getProperty("MAPS_API_KEY") 
                        ?: localProperties.getProperty("maps.api.key") 
                        ?: ""
        
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

    packaging {
        jniLibs {
            keepDebugSymbols.add("**/*.so")
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
    
    // Dependencias nativas de Firebase para ShutdownReceiver
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
}

// Tarea para generar google-services.json desde .env automáticamente
tasks.register("generateGoogleServices") {
    val envFile = rootProject.file("../.env")
    val templateFile = file("google-services.json.template")
    val outputFile = file("google-services.json")

    inputs.file(envFile).optional()
    inputs.file(templateFile).optional()
    outputs.file(outputFile)

    doLast {
        if (!envFile.exists()) {
            println("ALERTA: Archivo .env no encontrado en la raíz.")
            return@doLast
        }
        val env = Properties()
        envFile.inputStream().use { env.load(it) }
        val apiKey = env.getProperty("FIREBASE_API_KEY_ANDROID") ?: ""

        if (apiKey.isNotEmpty() && templateFile.exists()) {
            val content = templateFile.readText().replace("@@FIREBASE_API_KEY_ANDROID@@", apiKey)
            if (!outputFile.exists() || outputFile.readText() != content) {
                outputFile.writeText(content)
                println("INFO: google-services.json actualizado desde .env")
            }
        }
    }
}

// Asegurar que la tarea corra antes de que el plugin de Google Services procese el archivo
tasks.matching { it.name.startsWith("process") && it.name.endsWith("GoogleServices") }.all {
    dependsOn("generateGoogleServices")
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}
