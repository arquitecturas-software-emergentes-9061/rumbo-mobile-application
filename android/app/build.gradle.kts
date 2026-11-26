import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    rootProject.file("local.properties").takeIf { it.isFile }?.inputStream()?.use { load(it) }
}
val rumboLocalInstall = providers.gradleProperty("rumboLocalInstall")
    .orNull ?: localProperties.getProperty("rumboLocalInstall", "false")

android {
    namespace = "com.uitopic.rumbo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.uitopic.rumbo"
        minSdk = if (project.findProject(":unityLibrary") != null) maxOf(flutter.minSdkVersion, 25) else flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["rumboAppLabel"] = "Rumbo"
    }

    buildTypes {
        debug {
            if (rumboLocalInstall.toBoolean()) {
                applicationIdSuffix = ".local"
                manifestPlaceholders["rumboAppLabel"] = "Rumbo local"
            }
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    if (project.findProject(":unityLibrary") != null) {
        implementation(project(":unityLibrary"))
    }
}
