import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: create android/key.properties (git-ignored) with
//   storePassword=...  keyPassword=...  keyAlias=...  storeFile=/path/to/upload-keystore.jks
// Without it, release builds fall back to the debug key (fine for local testing only).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Values passed with --dart-define (Flutter hands them to Gradle base64 encoded).
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.mapNotNull { encoded ->
        val pair = String(Base64.getDecoder().decode(encoded))
        val i = pair.indexOf('=')
        if (i > 0) pair.substring(0, i) to pair.substring(i + 1) else null
    }
    ?.toMap() ?: emptyMap()

// Facebook Login: --dart-define=FACEBOOK_APP_ID=... --dart-define=FACEBOOK_CLIENT_TOKEN=...
// Without them the Facebook button stays hidden and the SDK has nothing to start.
val facebookAppId = dartDefines["FACEBOOK_APP_ID"].orEmpty()
val facebookClientToken = dartDefines["FACEBOOK_CLIENT_TOKEN"].orEmpty()

android {
    namespace = "com.afriva.afriva_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        resValues = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.afriva.afriva_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "facebook_app_id", facebookAppId.ifEmpty { "0" })
        resValue("string", "facebook_client_token", facebookClientToken.ifEmpty { "0" })
        resValue("string", "fb_login_protocol_scheme", "fb" + facebookAppId.ifEmpty { "0" })
        manifestPlaceholders["facebookAutoInit"] = if (facebookAppId.isEmpty()) "false" else "true"
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
