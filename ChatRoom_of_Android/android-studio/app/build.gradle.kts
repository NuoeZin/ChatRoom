import java.util.Properties

plugins {
    id("com.android.application")
}

val signingProperties = Properties()
val signingFile = rootProject.file("keystore.properties")
if (signingFile.exists()) {
    signingFile.inputStream().use(signingProperties::load)
}

android {
    namespace = "com.nuoezin.chatroom"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.nuoezin.chatroomnative"
        minSdk = 23
        targetSdk = 36
        versionCode = 20200
        versionName = "2.2.0"

        vectorDrawables.useSupportLibrary = true
        resourceConfigurations += listOf("zh", "en")
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                storeFile = rootProject.file(signingProperties["storeFile"] as String)
                storePassword = signingProperties["storePassword"] as String
                keyAlias = signingProperties["keyAlias"] as String
                keyPassword = signingProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            if (signingFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    packaging {
        resources.excludes += setOf(
            "META-INF/AL2.0",
            "META-INF/LGPL2.1",
            "META-INF/*.kotlin_module"
        )
    }
}

dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity:1.9.3")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    implementation("com.google.android.material:material:1.12.0")
}
