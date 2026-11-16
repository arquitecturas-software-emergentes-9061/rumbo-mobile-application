pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

val unityLibraryDirectory = file("../../rumbo-ar-unity/Builds/Android/unityLibrary")
if (unityLibraryDirectory.isDirectory) {
    include(":unityLibrary")
    project(":unityLibrary").projectDir = unityLibraryDirectory
    unityLibraryDirectory.listFiles()?.filter { child ->
        child.isDirectory && (File(child, "build.gradle").isFile || File(child, "build.gradle.kts").isFile)
    }?.forEach { child ->
        include(":unityLibrary:${child.name}")
        project(":unityLibrary:${child.name}").projectDir = child
    }
}
