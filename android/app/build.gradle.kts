import java.util.Properties

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
        versionCode = 62
        versionName = "4.9.1"
        // 筆跡引擎的正確性只有在真的 Android runtime 上才驗得出來
        // （MotionEvent、密度換算、JNA 載入 .so 都不是純 JVM 模擬得了的）。
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    // 發佈簽章設定。
    //
    // 金鑰與密碼**不進版控** —— 它們放在 android/keystore.properties（已忽略）
    // 或同名的環境變數裡。沒有設定時 release 版就是未簽章的，
    // 建置仍然會成功，只是不能上架 —— 這比「靜默用 debug 金鑰簽下去」好：
    // 用 debug 金鑰簽的 AAB 上傳 Play Console 會被拒絕，而錯誤訊息不會告訴你原因。
    val keystoreProperties = Properties().apply {
        val file = rootProject.file("keystore.properties")
        if (file.exists()) file.inputStream().use { load(it) }
    }
    fun key(name: String): String? =
        keystoreProperties.getProperty(name) ?: System.getenv("KAIRUMO_${name.uppercase()}")

    signingConfigs {
        if (key("storeFile") != null) {
            create("release") {
                storeFile = file(key("storeFile")!!)
                storePassword = key("storePassword")
                keyAlias = key("keyAlias")
                keyPassword = key("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 不開混淆：UniFFI 的 Kotlin 綁定透過 JNA 以**名稱**對應原生符號，
            // 被重新命名之後會在執行期才炸開，而且是在使用者手上炸。
            // 體積的代價（約 2MB）換一個不會在半夜出事的發佈版本，值得。
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfigs.findByName("release")?.let { signingConfig = it }
        }
    }

    // AAB 依 ABI 切分：Play 只會下發使用者裝置需要的那一個 .so。
    // 兩個 ABI 各約 7MB，不切的話每個使用者都多下載一份用不到的。
    bundle {
        abi { enableSplit = true }
        language { enableSplit = false }  // 六國語系在同一份字串表裡，切了會缺字
        density { enableSplit = true }
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

    // 說明手冊與隱私權政策取自 repo 的 docs/，不在 android/ 再放一份副本 ——
    // 兩份文件遲早會不一致，而且不一致的那一份會出現在使用者手上。
    //
    // **只複製這兩個子目錄。** 直接把整個 docs/ 掛成 assets 的話，
    // DEVLOG、TODO、ADR、內部計畫全都會隨 APK 出貨給使用者。
    sourceSets["main"].assets.srcDirs(layout.buildDirectory.dir("generated/docsAssets"))

    // 一致性向量（閘門 1）**只掛在測試上**，不進 APK ——
    // 它是給測試比對用的期望值，使用者的手機上一個位元組都不該有。
    sourceSets["androidTest"].assets.srcDirs(layout.buildDirectory.dir("generated/conformance"))

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

/** 只把要給使用者看的文件複製進 assets。 */
val copyUserDocs by tasks.registering(Copy::class) {
    from("$rootDir/../docs/manual") {
        into("manual")
        include("img/**")
    }
    from("$rootDir/../docs/manual/index-android.html") {
        into("manual")
        rename("index-android.html", "index.html")
    }
    from("$rootDir/../docs/manual/manual-android.js") {
        into("manual")
        rename("manual-android.js", "manual.js")
    }
    from("$rootDir/../docs/legal/privacy-android.html") {
        into("legal")
        rename("privacy-android.html", "privacy.html")
    }
    // 文件範本目錄（工作項 S-61）。與手冊走同一條路：repo 裡只有一份，
    // 建置時複製進 assets，兩個平台載入的是同一個檔案。
    from("$rootDir/../templates/document-templates.json") { into("templates") }
    into(layout.buildDirectory.dir("generated/docsAssets"))
}

/** 一致性向量（由核心產生，見 crates/padnote-core/tests/conformance_vectors.rs）。 */
val copyConformanceVectors by tasks.registering(Copy::class) {
    from("$rootDir/../docs/conformance") { into("conformance") }
    into(layout.buildDirectory.dir("generated/conformance"))
}

// 任何會讀到 assets 的工作都要等複製完成。只掛 merge*Assets 的話，
// lint 與打包流程會在檔案還沒到位時就去讀那個目錄，Gradle 會直接擋下來。
tasks.matching {
    it.name.contains("Assets") || it.name.startsWith("lint") ||
        it.name.startsWith("generate") && it.name.contains("Lint")
}.configureEach { dependsOn(copyUserDocs, copyConformanceVectors) }

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.ui:ui-tooling-preview")

    // 使用者自己的雲端硬碟（Google Drive 等）以 SAF 的 DocumentsProvider 呈現，
    // 沒有 POSIX 路徑 —— 只能透過 DocumentFile 讀寫。
    implementation("androidx.documentfile:documentfile:1.0.1")

    // 前緩衝渲染（低延遲手寫）。需要 API 29 以上 —— minSdk 就是為它訂的。
    implementation("androidx.graphics:graphics-core:1.0.2")
    // 預測筆跡。補的是「手已經到了、畫面還沒跟上」的那一段視覺落差。
    implementation("androidx.input:input-motionprediction:1.0.0-beta05")

    // 手寫辨識。ML Kit 是既有架構決策 D2 已接受的例外（需要 Google Play 服務），
    // 沒有服務的裝置要明確降級，不能靜默失敗。
    implementation("com.google.mlkit:digital-ink-recognition:18.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.9.0")

    // OAuth 要在系統瀏覽器裡完成 —— Google 會拒絕 WebView 裡的授權
    // （disallowed_useragent），而且 WebView 拿不到使用者已登入的 session。
    implementation("androidx.browser:browser:1.8.0")

    // refresh token 等同「不必再問密碼就能存取雲端硬碟」的長期憑證，
    // 不可以明文躺在 SharedPreferences 的 XML 裡。
    implementation("androidx.security:security-crypto:1.1.0-alpha06")

    // 協同編輯的 WebSocket。Android 沒有 java.net.http（那是 JDK 11 的東西），
    // 也沒有 URLSession 的對應品 —— OkHttp 是這裡唯一實務上的選擇。
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    // 背景同步。App 在背景時行程隨時會被收掉，前景的計時器跟著停 ——
    // 沒有它的話，使用者把 App 切走之後寫的東西要等下次打開才會上雲。
    // WorkManager 是唯一會處理 Doze、開機重啟與重試的排程器。
    implementation("androidx.work:work-runtime-ktx:2.9.1")

    // 折疊機的姿態（鉸鏈在哪、闔起還是攤開）。Configuration 只給得出寬度，
    // 給不出「畫面中間橫著一條鉸鏈」—— 內容壓在鉸鏈上是折疊機最明顯的毛病。
    implementation("androidx.window:window:1.3.0")

    // UniFFI 產生的 Kotlin 綁定透過 JNA 呼叫 libpadnote_core.so
    implementation("net.java.dev.jna:jna:5.15.0@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")

    debugImplementation("androidx.compose.ui:ui-tooling")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:rules:1.6.1")
    // 整個 App 的 Compose 測試（畫面稽核）。在此之前 androidTest 全是
    // 直接呼叫函式的單元式測試，沒有任何一條會把 App 真的跑起來。
    androidTestImplementation(platform("androidx.compose:compose-bom:2024.10.01"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    debugImplementation("androidx.compose.ui:ui-test-manifest")
}
