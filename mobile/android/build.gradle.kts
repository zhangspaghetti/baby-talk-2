import com.android.build.gradle.LibraryExtension
import org.gradle.api.tasks.Delete

buildscript {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/public/") }
        maven { url = uri("https://maven.aliyun.com/repository/spring/")}
        maven { url = uri("https://maven.aliyun.com/repository/google/")}
        maven { url = uri("https://maven.aliyun.com/repository/gradle-plugin/")}
        maven { url = uri("https://maven.aliyun.com/repository/spring-plugin/")}
        maven { url = uri("https://maven.aliyun.com/repository/grails-core/")}
        maven { url = uri("https://maven.aliyun.com/repository/apache-snapshots/")}
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.13.2")
    }
}

allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/public/") }
        maven { url = uri("https://mirrors.huaweicloud.com/repository/maven/") }
        google() // Android项目必需
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(name)
    layout.buildDirectory.value(newSubprojectBuildDir)
    evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            if (namespace.isNullOrBlank()) {
                namespace = when (project.name) {
                    "isar_flutter_libs" -> "dev.isar.isar_flutter_libs"
                    else -> "dev.flutter.${project.name.replace('-', '_')}"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
