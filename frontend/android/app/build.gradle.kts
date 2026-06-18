import java.io.File

// Materialize google-services.json from local secrets before the Google Services plugin runs.
run {
    val localSecrets = file("google-services.local.json")
    val target = file("google-services.json")
    when {
        localSecrets.isFile -> localSecrets.copyTo(target, overwrite = true)
        !target.isFile -> logger.warn(
            "Missing android/app/google-services.json — copy google-services.json.example " +
                "to google-services.local.json and download your file from Firebase console.",
        )
    }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

/**
 * Maps SDK reads the key from AndroidManifest (not Dart .env).
 * Prefer `android/secrets.properties`; fall back to `frontend/.env`.
 */
fun loadSecretsProperties(): Map<String, String> {
    val secretsFile = File(rootProject.projectDir, "secrets.properties")
    if (!secretsFile.isFile) return emptyMap()

    val props = mutableMapOf<String, String>()
    for (rawLine in secretsFile.readLines()) {
        val line = rawLine.trim()
        if (line.isEmpty() || line.startsWith("#")) continue
        val eq = line.indexOf('=')
        if (eq <= 0) continue
        props[line.substring(0, eq).trim()] = line.substring(eq + 1).trim().trim('"')
    }
    return props
}

fun resolveGoogleMapsApiKey(): String {
    val fromSecrets = loadSecretsProperties()["GOOGLE_MAPS_API_KEY"]?.trim().orEmpty()
    if (fromSecrets.isNotEmpty() && !fromSecrets.contains("your_key", ignoreCase = true)) {
        return fromSecrets
    }

    val fromGradle =
        (project.findProperty("GOOGLE_MAPS_API_KEY") as String?)?.trim().orEmpty()
    if (fromGradle.isNotEmpty() && !fromGradle.contains("your_key", ignoreCase = true)) {
        return fromGradle
    }

    val envFile = File(rootProject.projectDir.parentFile, ".env")
    if (!envFile.isFile) return fromGradle

    for (rawLine in envFile.readLines()) {
        val line = rawLine.trim()
        if (line.isEmpty() || line.startsWith("#")) continue
        if (!line.startsWith("GOOGLE_MAPS_API_KEY=")) continue
        val value = line.substringAfter("=").trim().trim('"')
        if (value.isNotEmpty() && !value.contains("your_key", ignoreCase = true)) {
            return value
        }
    }
    return fromGradle
}

android {
    namespace = "com.example.meatvo_official"

    // Change 1: Update compileSdk to 36
    compileSdk = 36 
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Must match Google Cloud Console → API key → Android app restriction.
        applicationId = "com.meatvo.app"

        minSdk = flutter.minSdkVersion
        // Change 2: Update targetSdk to 36
        targetSdk = 36 

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val mapsApiKey = resolveGoogleMapsApiKey()
        if (mapsApiKey.isEmpty()) {
            logger.warn(
                "GOOGLE_MAPS_API_KEY is empty — map tiles will not load. " +
                    "Set GOOGLE_MAPS_API_KEY in frontend/.env or android/secrets.properties",
            )
        }
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        create("release") {
            val keystorePath = (project.findProperty("MEATVO_KEYSTORE_PATH") as String?)?.trim().orEmpty()
            val keystorePassword = (project.findProperty("MEATVO_KEYSTORE_PASSWORD") as String?)?.trim().orEmpty()
            val keyAlias = (project.findProperty("MEATVO_KEY_ALIAS") as String?)?.trim().orEmpty().ifEmpty { "meatvo" }
            val keyPassword = (project.findProperty("MEATVO_KEY_PASSWORD") as String?)?.trim().orEmpty()

            if (keystorePath.isNotEmpty() && keystorePassword.isNotEmpty()) {
                storeFile = file(keystorePath)
                storePassword = keystorePassword
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword.ifEmpty { keystorePassword }
            }
        }
    }

    buildTypes {
        release {
            val releaseSigning = signingConfigs.getByName("release")
            if (releaseSigning.storeFile == null) {
                error(
                    "Release signing not configured. Set MEATVO_KEYSTORE_PATH and " +
                        "MEATVO_KEYSTORE_PASSWORD (and optionally MEATVO_KEY_ALIAS / " +
                        "MEATVO_KEY_PASSWORD) in gradle.properties or environment.",
                )
            }
            signingConfig = releaseSigning
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") 
}

flutter {
    source = "../.."
}