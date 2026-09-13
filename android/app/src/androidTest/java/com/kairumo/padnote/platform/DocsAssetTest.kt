package com.kairumo.padnote.platform

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
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
    fun everyDocumentIsACompleteHtmlDocument() {
        // 這兩份文件現在是完整的 HTML，DocsViewer 直接 loadUrl 就好。
        //
        // 少了 charset 宣告，WebView 只能猜編碼，中文會整頁變成亂碼 ——
        // Apple 端實際發生過這件事，使用者回報了才發現。
        // 少了 viewport，手機上會用桌面寬度排版，整頁縮成看不清的小字。
        for (path in listOf("manual/index.html", "legal/privacy.html")) {
            val html = assets.open(path).bufferedReader().use { it.readText() }
            assertTrue("$path 沒有 DOCTYPE", html.trimStart().startsWith("<!DOCTYPE html>", true))
            assertTrue("$path 缺少編碼宣告，會顯示成亂碼",
                html.contains("<meta charset=\"utf-8\">", ignoreCase = true))
            assertTrue("$path 缺少 viewport，手機上會縮成小字",
                html.contains("name=\"viewport\"", ignoreCase = true))
        }
    }

    @Test
    fun documentsDoNotNameOperatingSystems() {
        // 同一份手冊要給所有平台的使用者看。列出某個平台的名字，
        // 會讓其他平台的使用者以為那些功能自己沒有。
        val forbidden = listOf("iPad", "iPhone", "iOS", "macOS", "Android", "Apple Pencil", "iCloud")
        for (path in listOf("manual/index.html", "manual/manual.js", "legal/privacy.html")) {
            val text = assets.open(path).bufferedReader().use { it.readText() }
            for (word in forbidden) {
                assertFalse("$path 裡出現了「$word」", text.contains(word))
            }
        }
    }

    @Test
    fun theManualCoversBackupAndSync() {
        // 使用者問過「備份的功能在哪裡」—— 手冊裡沒有這一段，
        // 那本身就是問題的一部分。六個語系都要有。
        val manual = assets.open("manual/manual.js").bufferedReader().use { it.readText() }
        assertEquals(6, manual.split("id: \"data\"").size - 1)
    }
}
