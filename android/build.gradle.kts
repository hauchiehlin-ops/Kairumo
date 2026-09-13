// Kairumo Android 外殼（工作包 WP2）
//
// Rust 核心以 libpadnote_core.so 的形式打包進 APK，介面由 UniFFI 產生的
// Kotlin 綁定提供 —— 與 Apple 版共用同一份核心與同一個資料格式。
plugins {
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
}
