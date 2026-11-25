val unityAarDirectory = findProject(":unityLibrary")?.file("libs")

allprojects {
    repositories {
        google()
        mavenCentral()
        if (unityAarDirectory?.isDirectory == true) {
            flatDir { dirs(unityAarDirectory) }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
