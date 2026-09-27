allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
    .dir("../../.android_build")
        .get()
val flutterBuildDir: Directory =
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

val copyFlutterReleaseOutputs by tasks.registering(Copy::class) {
    from(newBuildDir.dir("app/outputs"))
    into(flutterBuildDir.dir("app/outputs"))
    includeEmptyDirs = false
}

project(":app") {
    tasks.matching {
        it.name == "assembleRelease" ||
            it.name == "bundleRelease" ||
            it.name == "packageReleaseBundle"
    }.configureEach {
        finalizedBy(rootProject.tasks.named("copyFlutterReleaseOutputs"))
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
