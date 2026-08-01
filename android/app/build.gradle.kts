import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// قراءة بيانات توقيع الإصدار من android/key.properties إن وُجدت.
// ضع نسخة حقيقية بناءً على key.properties.example (لا تُرفع للمستودع).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ali.menbaradkshk"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time via desugaring).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.ali.menbaradkshk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // يستخدم مفتاح الإصدار الحقيقي عند توفّر android/key.properties،
            // وإلا يعود لمفتاح debug حتى يعمل `flutter run --release` محلياً.
            // ⚠️ لا تَرفع أي AAB موقَّع بمفتاح debug إلى Google Play.
            signingConfig = if (hasReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            // تقليص R8 للكود + الموارد (خفض الحجم). قواعد keep في
            // proguard-rules.pro — لا تحذفها؛ حذفها قد يكسر الإشعارات المجدولة.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// إزالة SafetyNet Attestation المُهملة من Google (أبلغ عنها Play Console).
// التطبيق يستخدم Play Integrity لـ App Check ولا يستعمل مصادقة الهاتف، فمكتبة
// play-services-safetynet التي يجرّها firebase-auth ميتة تماماً؛ استبعادها يزيل
// الواجهة المهملة دون أي أثر وظيفي. (مزوّد App Check القديم أُسقط بترقية
// firebase_app_check إلى 0.3.2.)
configurations.all {
    exclude(group = "com.google.android.gms", module = "play-services-safetynet")
}

flutter {
    source = "../.."
}
