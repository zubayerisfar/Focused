import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()

if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && !hasReleaseKeystore) {
    throw GradleException(
        "Focused release signing is not configured. Copy android/key.properties.example " +
            "to android/key.properties and point it to one stable release/upload keystore. " +
            "Do not ship a release APK signed by a machine-specific debug key because Google OAuth SHA fingerprints will differ."
    )
}

android {
    namespace = "com.focused.focused_android"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.focused.focused_android"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // A stable signing certificate is mandatory for release builds.
            // Debug signing is intentionally not used as a release fallback.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }

            // Strips unused Java/Kotlin code, Firebase libraries, and reduces DEX size drastically
            isMinifyEnabled = true
            // Strips unused assets, layouts, and drawables from dependencies
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4"
    )
}
