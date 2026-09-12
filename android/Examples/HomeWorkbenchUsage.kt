package com.padnote.examples

import android.content.Context
import uniffi.padnote_core.coreVersion
import uniffi.padnote_core.appInfo
import uniffi.padnote_core.localizedVersionString
import uniffi.padnote_core.FfiLocale

/**
 * Android 平台首頁「今日工作台」與版本號整合範例（docs/ui-design.md §2.1）。
 *
 * 滿足跨平台架構要求：
 * 1. 核心版本號統一來自 Rust Core（[coreVersion] 與 [appInfo]），保證各平台同步不脫節。
 * 2. 支援在地化版本文字標記（[localizedVersionString]）。
 * 3. 跨平台資料模型與版面結構對齊 iOS / Mac Catalyst。
 */
object HomeWorkbenchUsage {

    data class WorkbenchState(
        val appName: String,
        val version: String,
        val localizedVersion: String,
        val targetOs: String,
        val targetArch: String,
        val buildProfile: String
    )

    /**
     * 讀取跨平台核心版本與環境診斷資訊。
     */
    fun loadWorkbenchState(locale: FfiLocale = FfiLocale.TRADITIONAL_CHINESE): WorkbenchState {
        val info = appInfo()
        val locVer = localizedVersionString(locale)
        return WorkbenchState(
            appName = info.name,
            version = "v${info.version}",
            localizedVersion = locVer,
            targetOs = info.targetOs,
            targetArch = info.targetArch,
            buildProfile = info.buildProfile
        )
    }

    /**
     * 取得供首頁底部或 Drawer / 側邊欄顯示的版本標籤字串。
     * 例如："Kairumo v0.1.4 (Android / aarch64)"
     */
    fun getFooterVersionLabel(): String {
        val version = coreVersion()
        return "Kairumo v$version"
    }
}
