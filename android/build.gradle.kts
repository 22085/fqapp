allprojects {
    repositories {
        val useMirrors = providers.environmentVariable("FQAPP_USE_MAVEN_MIRRORS")
            .orNull?.equals("false", ignoreCase = true) != true
        if (useMirrors) {
            maven { url = uri("https://maven.aliyun.com/repository/google") }
            maven { url = uri("https://maven.aliyun.com/repository/central") }
            maven { url = uri("https://maven.aliyun.com/repository/public") }
        }
        google()
        mavenCentral()
        // Vendored Huijing AARs (plugins/flutter_ads_plugin/android/libs),
        // declared as flatDir coordinates in the plugin's build.gradle.
        // This MUST live here (allprojects), not only in the plugin: when
        // :app resolves the plugin's transitive dependencies, only the
        // consuming project's repositories are consulted, so a flatDir
        // declared in the plugin alone is invisible and every AAR
        // fails with "Could not find :<name>:". Path is anchored at the
        // root project (android/) so it resolves the same in every
        // subproject.
        flatDir {
            dirs(rootProject.file("../plugins/flutter_ads_plugin/android/libs"))
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
