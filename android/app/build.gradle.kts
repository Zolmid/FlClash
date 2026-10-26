import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val zolnitKeystorePath = System.getenv("ZOLNIT_ANDROID_KEYSTORE_PATH")
val zolnitKeystorePassword = System.getenv("ZOLNIT_ANDROID_KEYSTORE_PASSWORD")
val zolnitKeyAlias = System.getenv("ZOLNIT_ANDROID_KEY_ALIAS")
val zolnitKeyPassword = System.getenv("ZOLNIT_ANDROID_KEY_PASSWORD")
val hasZolnitSigning = run {
    val values = listOf(zolnitKeystorePath, zolnitKeystorePassword, zolnitKeyAlias, zolnitKeyPassword)
    values.all { !it.isNullOrBlank() } &&
        zolnitKeystorePath!!.let { file(it).isFile }
}

android {
    namespace = "com.zolmid.zolnit"
    compileSdk = libs.versions.compileSdk.get().toInt()
    ndkVersion = libs.versions.ndkVersion.get()

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zolmid.zolnit"
        minSdk = flutter.minSdkVersion
        targetSdk = libs.versions.targetSdk.get().toInt()
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasZolnitSigning) {
            create("release") {
                storeFile = file(zolnitKeystorePath!!)
                storePassword = zolnitKeystorePassword
                keyAlias = zolnitKeyAlias
                keyPassword = zolnitKeyPassword
            }
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            applicationIdSuffix = ".debug"
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (hasZolnitSigning) {
                signingConfig = signingConfigs.getByName("release")
            }

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    sourceSets {
        // Unit tests live under android/tests/ instead of each module's src/test.
        getByName("test").java.setSrcDirs(listOf("../tests/app"))
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

if (!hasZolnitSigning) {
    val releaseGuard by tasks.registering {
        doFirst {
            throw GradleException(
                "Release signing requires ZOLNIT_ANDROID_KEYSTORE_PATH, " +
                    "ZOLNIT_ANDROID_KEYSTORE_PASSWORD, ZOLNIT_ANDROID_KEY_ALIAS, " +
                    "and ZOLNIT_ANDROID_KEY_PASSWORD environment variables " +
                    "pointing to a valid keystore file."
            )
        }
    }
    tasks.configureEach {
        if (name.matches(Regex("(assemble|bundle|package|sign).*Release(Bundle)?"))) {
            dependsOn(releaseGuard)
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(project(":service"))
    implementation(project(":flutter_secure_storage"))
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation(project(":common"))
    implementation(project(":core"))
    implementation(libs.core.splashscreen)
    implementation(libs.gson)
    implementation(libs.smali.dexlib2) {
        exclude(group = "com.google.guava", module = "guava")
    }
    testImplementation(libs.junit)
    testImplementation("org.json:json:20250517")
    testImplementation(libs.kotlinx.coroutines.test)
}
