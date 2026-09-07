allprojects {
    repositories {
        google()
        mavenCentral()
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
    project.pluginManager.withPlugin("com.android.library") {
        val androidComponents = project.extensions.findByType(com.android.build.api.variant.AndroidComponentsExtension::class.java)
        androidComponents?.finalizeDsl { extension ->
            try {
                val method = extension?.javaClass?.getMethod("setCompileSdk", java.lang.Integer::class.java)
                method?.invoke(extension, 36)
            } catch (e: Exception) {
                project.logger.error("Failed to set compileSdk via finalizeDsl", e)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
