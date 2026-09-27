import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (!keystorePropertiesFile.exists()) {
    throw GradleException("Missing key.properties at ${keystorePropertiesFile.absolutePath}")
}
keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }

val releaseStoreFilePath = (keystoreProperties["storeFile"] as String?)?.trim()
    ?: throw GradleException("storeFile is missing in key.properties")
val releaseStoreFile = file(releaseStoreFilePath)
if (!releaseStoreFile.exists()) {
    throw GradleException("Release keystore not found at: ${releaseStoreFile.absolutePath}")
}

android {
    namespace = "com.stefanronnkvist.paid.schedular"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stefanronnkvist.paid.schedular"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = (keystoreProperties["keyAlias"] as String?)?.trim()
            keyPassword = (keystoreProperties["keyPassword"] as String?)?.trim()
            storeFile = releaseStoreFile
            storePassword = (keystoreProperties["storePassword"] as String?)?.trim()
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
