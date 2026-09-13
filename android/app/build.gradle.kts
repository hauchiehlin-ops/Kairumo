plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

android {
    namespace = "com.kairumo.padnote"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.kairumo.padnote"
        // minSdk 29：androidx.graphics.lowlatency 的前緩衝渲染需要 Android 10 以上，
        // 那是手寫延遲的關鍵，不為舊機另寫一條渲染路徑。
        minSdk = 29
        targetSdk = 35
        // 版本號由 scripts/bump-version.sh 與 Apple 端一起更新，不要手改
        versionCode = 15
        versionName = "2.3.4"
        // 筆跡引擎的正確性只有在真的 Android runtime 上才驗得出來
        // （MotionEvent、密度換算、JNA 載入 .so 都不是純 JVM 模擬得了的）。
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    buildFeatures {
        compose = true
        // 讓畫面顯示的版本直接取自建置設定，不要再手寫一份會過期的字串
        buildConfig = true
    }

    // libpadnote_core.so 由 scripts/build-android-libs.sh 產生
    sourceSets["main"].jniLibs.srcDirs("src/main/jniLibs")

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")

    // 前緩衝渲染（低延遲手寫）。需要 API 29 以上 —— minSdk 就是為它訂的。
    implementation("androidx.graphics:graphics-core:1.0.2")
    // 預測筆跡。補的是「手已經到了、畫面還沒跟上」的那一段視覺落差。
    implementation("androidx.input:input-motionprediction:1.0.0-beta05")

    // UniFFI 產生的 Kotlin 綁定透過 JNA 呼叫 libpadnote_core.so
    implementation("net.java.dev.jna:jna:5.15.0@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
}
