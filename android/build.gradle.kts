// Kairumo Android 外殼（工作包 WP2）
//
// Rust 核心以 libpadnote_core.so 的形式打包進 APK，介面由 UniFFI 產生的
// Kotlin 綁定提供 —— 與 Apple 版共用同一份核心與同一個資料格式。
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}

// 專案在 exFAT 外接碟時，把各模組的 build 目錄放到本機磁碟。exFAT 上 Gradle 的中介產物旁
// 會生出 `._*`，造成 "… is not a directory" 之類的錯誤。路徑由 settings.gradle.kts 決定
// （scripts/lib-exfat.sh 設的 KAIRUMO_GRADLE_BUILD_ROOT 優先，否則非 APFS 磁碟自動導到本機）；
// APFS 上沒有這個值，行為不變。
(gradle.extensions.extraProperties.properties["kairumoBuildRoot"] as String?)?.let { root ->
    allprojects {
        layout.buildDirectory.set(file("$root/${project.name}"))
    }
}
