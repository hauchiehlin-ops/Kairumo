package com.kairumo.padnote.platform

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 隨 APK 出貨的文件（工作包 WP6）。
 *
 * 這些是「打包設定對不對」的測試。檔案漏掉的話，使用者點下去看到的是
 * 一片空白的 WebView；而多帶了不該帶的，則是把開發日誌送到使用者手上。
 */
@RunWith(AndroidJUnit4::class)
class DocsAssetTest {

    private val assets = InstrumentationRegistry.getInstrumentation().targetContext.assets

    @Test
    fun manualAndPrivacyPolicyAreBundled() {
        assertTrue(assets.list("manual")!!.contains("index.html"))
        assertTrue(assets.list("manual")!!.contains("manual.js"))
        assertTrue(assets.list("legal")!!.contains("privacy.html"))
    }

    @Test
    fun manualScreenshotsAreBundled() {
        // 手冊的重點就是「按鈕長什麼樣」。圖沒帶到的話，整份說明等於廢掉。
        val images = assets.list("manual/img") ?: emptyArray()
        assertTrue("手冊的截圖沒有隨 APK 出貨（${images.size} 張）", images.size > 5)
    }

    @Test
    fun internalDevelopmentDocsAreNotShipped() {
        // 直接把整個 docs/ 掛成 assets 的話，DEVLOG、TODO、ADR、內部計畫
        // 全都會隨 APK 出貨給使用者。這條測試就是為了擋那次手滑。
        val root = assets.list("") ?: emptyArray()
        for (leaked in listOf("DEVLOG.md", "TODO.md", "STATE.md", "adr", "plans")) {
            assertFalse("內部文件外洩到 APK：$leaked", root.contains(leaked))
        }
    }

    @Test
    fun manualIsReadableAndNotEmpty() {
        val html = assets.open("manual/index.html").bufferedReader().use { it.readText() }
        assertTrue("手冊內容太短，可能沒複製完整", html.length > 1_000)
        assertTrue("手冊應該帶標題", html.contains("<title", ignoreCase = true))
    }

    @Test
    fun theManualIsAFragmentSoTheViewerMustWrapIt() {
        // 這兩份文件是為了網頁發佈而寫的片段，沒有 <html> 也沒有 viewport meta。
        // 直接丟給 WebView 會用桌面寬度排版，手機上整頁縮成看不清的小字。
        // DocsViewer 負責補外框 —— 這條測試釘住「它確實是片段」這個前提，
        // 哪天來源改成完整文件，這裡會提醒去簡化 DocsViewer。
        val html = assets.open("manual/index.html").bufferedReader().use { it.readText() }
        assertFalse(html.contains("<html", ignoreCase = true))
        assertFalse(html.contains("name=\"viewport\"", ignoreCase = true))
    }
}
