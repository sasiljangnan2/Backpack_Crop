import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 출시용 서명 키. android/key.properties가 있으면 그 키로 서명한다 (저장소에 올리지 않는다).
// 없으면 디버그 키로 서명한다 (로컬에서 release 빌드를 확인할 때만 쓴다. 스토어에는 올릴 수 없다)
//   storeFile=../upload-keystore.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasReleaseKey = keyProperties.getProperty("storeFile") != null

// flutter build/run의 --dart-define 값 (Flutter가 base64로 묶어 dart-defines 속성으로 넘긴다).
// GOOGLE_MAPS_API_KEY를 AndroidManifest의 구글 지도 키로 넣는다. 키는 저장소에 넣지 않고 빌드할 때만 준다
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    .orEmpty()
    .split(",")
    .filter { it.isNotBlank() }
    .mapNotNull { encoded ->
        val decoded = try {
            String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
        } catch (e: IllegalArgumentException) {
            null
        }
        val pair = decoded?.split("=", limit = 2)
        if (pair != null && pair.size == 2) pair[0] to pair[1] else null
    }
    .toMap()

android {
    namespace = "com.backpackcorp.backpack"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.backpackcorp.backpack"
        // firebase_messaging · flutter_secure_storage가 요구하는 최소 버전
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = dartDefines["GOOGLE_MAPS_API_KEY"] ?: ""
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
