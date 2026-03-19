import com.android.build.gradle.LibraryExtension
import com.android.build.api.dsl.ApplicationExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    // Configure namespace for better_player plugin
    afterEvaluate {
        if (project.name == "better_player") {
            extensions.findByName("android")?.let { androidExt ->
                if (androidExt is com.android.build.gradle.LibraryExtension) {
                    androidExt.namespace = "com.jhomlala.better_player"
                }
            }
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

subprojects {
    if (project.name == "better_player") {
        plugins.withId("com.android.library") {
            extensions.findByType(LibraryExtension::class.java)?.apply {
                namespace = "com.jhomlala.better_player"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
