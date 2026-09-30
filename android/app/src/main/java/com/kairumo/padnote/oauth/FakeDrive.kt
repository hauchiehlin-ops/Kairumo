package com.kairumo.padnote.oauth

/**
 * 多裝置測試用的掛勾：把 Google Drive 換成本機的假伺服器
 * （`scripts/fake-drive-server.py`）。與 Apple 端的 `FakeDriveHook.swift` 是同一套。
 *
 * # 為什麼需要它
 *
 * 模擬器上登入不了 Google，所以「A 刪除 → B 確認 → 期滿後雲端清除」「A 更名 → B 有沒有
 * 跟著改」這類**要兩個真正在跑的 App** 才驗證得了的行為，一直只能等實機。核心的傳輸層
 * （`FfiDriveHttp`）本來就是平台實作的，所以只要在測試模式下把 `https://www.googleapis.com`
 * 換成本機伺服器、並假裝已登入，模擬器上真實的 App 與真實的同步碼就能共用同一份「雲端」。
 *
 * # 只在設了系統屬性時生效
 *
 * `System.setProperty("kairumo.fakeDrive", "http://10.0.2.2:8765")`（`10.0.2.2` 是模擬器
 * 看到的這台 Mac 的 `127.0.0.1`）。沒設就完全不動；儀器測試與 App 在同一個行程裡，
 * 所以測試設了 App 就看得到。
 */
object FakeDrive {

    private const val REAL_HOST = "https://www.googleapis.com"

    private const val PROPERTY = "kairumo.fakeDrive"

    /** 假伺服器的位址。沒設定（正式版）就是 null。 */
    val baseUrl: String?
        get() = System.getProperty(PROPERTY)?.takeIf { it.isNotBlank() }?.trimEnd('/')

    val enabled: Boolean get() = baseUrl != null

    /** 假的權杖。**所有用這個掛勾的裝置共用同一個假帳號**，代表同一個使用者的多台裝置。 */
    const val ACCESS_TOKEN = "fake-drive-token"

    /** 把真的 Drive 網址換成假伺服器的；沒啟用或不是 Drive 網址就原樣回傳。 */
    fun rewrite(url: String): String {
        val base = baseUrl ?: return url
        return if (url.startsWith(REAL_HOST)) base + url.removePrefix(REAL_HOST) else url
    }
}
