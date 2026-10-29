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

    // Flutter plugins may declare an outdated compile SDK or omit a namespace.
    // Keep this before evaluationDependsOn(":app") so all subprojects are
    // configured before Gradle forces the app project to evaluate.
    afterEvaluate {
        val androidExtension =
            extensions.findByName("android") as? com.android.build.gradle.BaseExtension
                ?: return@afterEvaluate

        androidExtension.compileSdkVersion(35)

        if (androidExtension.namespace == null) {
            val manifest = file("src/main/AndroidManifest.xml")
            if (manifest.exists()) {
                val packageName = Regex("package\\s*=\\s*\"([^\"]+)\"")
                    .find(manifest.readText())
                    ?.groupValues
                    ?.get(1)
                if (packageName != null) {
                    androidExtension.namespace = packageName
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
