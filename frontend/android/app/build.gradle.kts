import java.io.File
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("keystore.properties")
    if (keystorePropertiesFile.isFile) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

fun keystoreProp(name: String): String =
    (keystoreProperties.getProperty(name)
        ?: project.findProperty(name) as String?
        ?: System.getenv(name))
        .orEmpty()
        .trim()

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
        else -> Unit
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
            val keystorePath = keystoreProp("MEATVO_KEYSTORE_PATH")
            val keystorePassword = keystoreProp("MEATVO_KEYSTORE_PASSWORD")
            val keyAlias = keystoreProp("MEATVO_KEY_ALIAS").ifEmpty { "meatvo" }
            val keyPassword = keystoreProp("MEATVO_KEY_PASSWORD")

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
            signingConfig = if (releaseSigning.storeFile != null) {
                releaseSigning
            } else {
                logger.warn(
                    "Release keystore not configured — signing APK with debug key (local testing only). " +
                        "Create android/keystore.properties from keystore.properties.example for production.",
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4") 
}

flutter {
    source = "../.."
}