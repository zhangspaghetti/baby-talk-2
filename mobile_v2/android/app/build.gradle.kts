import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePropertiesFile = rootProject.file("key.properties")
val releaseKeystoreProperties = Properties()
val hasReleaseSigningConfig = releaseKeystorePropertiesFile.exists().also { exists ->
    if (exists) {
        releaseKeystorePropertiesFile.inputStream().use(releaseKeystoreProperties::load)
    }
}
val releaseBuildRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

android {
    namespace = "com.babytalk.mobile_v2"
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
        applicationId = "com.babytalk.mobile_v2"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                val requiredKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
                val missingKeys = requiredKeys.filter {
                    releaseKeystoreProperties.getProperty(it).isNullOrBlank()
                }
                if (missingKeys.isNotEmpty()) {
                    throw GradleException(
                        "android/key.properties 缺少必要字段：${missingKeys.joinToString(", ")}。",
                    )
                }

                val configuredStoreFile = rootProject.file(
                    releaseKeystoreProperties.getProperty("storeFile"),
                )
                if (!configuredStoreFile.exists()) {
                    throw GradleException(
                        "Release signing keystore 不存在：${configuredStoreFile.path}。",
                    )
                }

                storeFile = configuredStoreFile
                storePassword = releaseKeystoreProperties.getProperty("storePassword")
                keyAlias = releaseKeystoreProperties.getProperty("keyAlias")
                keyPassword = releaseKeystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseBuildRequested) {
                throw GradleException(
                    "Release signing 未配置：请在 android/key.properties 中配置上传证书。",
                )
            }
        }
    }
}

flutter {
    source = "../.."
}
