package com.kairumo.padnote

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 核心（Rust）的診斷訊息是繁體中文；介面邊界依樣式表換成使用者的語言（對應 Apple 的
 * `CoreMessageTranslationTests`，兩邊的預期字串逐字相同）。
 */
@RunWith(AndroidJUnit4::class)
class CoreMessageTranslationTest {

    @After
    fun restore() = overrideLanguageForTest(null)

    private fun core(tag: String, message: String): String {
        overrideLanguageForTest(tag)
        return L10n.coreText(message)
    }

    private fun log(tag: String, message: String): String {
        overrideLanguageForTest(tag)
        return L10n.logText(message)
    }

    @Test
    fun aKnownMessageIsTranslatedAndKeepsItsDynamicPart() {
        assertEquals("Page not found: abc-123", core("en", "找不到頁面：abc-123"))
        assertEquals("ページが見つかりません: abc-123", core("ja", "找不到頁面：abc-123"))
        assertEquals("페이지를 찾을 수 없습니다: abc-123", core("ko", "找不到頁面：abc-123"))
        assertEquals("ไม่พบหน้า: abc-123", core("th", "找不到頁面：abc-123"))
        assertEquals("找不到页面：abc-123", core("zh-Hans", "找不到頁面：abc-123"))
    }

    @Test
    fun traditionalChineseIsLeftAlone() {
        assertEquals("找不到頁面：abc", core("zh-Hant", "找不到頁面：abc"))
        assertEquals("從來沒見過的訊息", core("zh-Hant", "從來沒見過的訊息"))
    }

    @Test
    fun nestedMessagesAndListsAreTranslatedRecursively() {
        assertEquals("Cannot read a.json: I/O error: Permission denied: x", core("en", "讀不到 a.json：IO 錯誤：權限不足：x"))
        assertEquals("Needs: Microphone, Handwriting recognition", core("en", "需要：麥克風、手寫辨識"))
        assertEquals("必要なもの: マイク、手書き認識", core("ja", "需要：麥克風、手寫辨識"))
    }

    @Test
    fun runsOfWhitespaceDoNotBreakMatching() {
        val long = "這本筆記是在復原碼還不能解鎖的版本建立的 ——                  它的復原碼從來沒有被用來包住金鑰，只有密碼開得了"
        assertTrue(core("en", long).startsWith("This notebook was created"))
    }

    @Test
    fun anUnknownChineseMessageFallsBackToTheGenericOne() {
        overrideLanguageForTest("en")
        assertEquals(L10n.t("error_generic"), L10n.coreText("一則沒有登記的新訊息"))
        assertEquals("plain english from the system", L10n.coreText("plain english from the system"))
    }

    @Test
    fun syncLogLinesAreTranslatedAtDisplayTimeButUnknownOnesPassThrough() {
        assertEquals("[Folder sync] All done.", log("en", "【資料夾同步】全部完成。"))
        assertEquals("Step 2 done. Uploaded: 3, downloaded: 1, new: 0", log("en", "步驟 2 完成。上傳: 3, 下載: 1, 新增: 0"))
        assertEquals("某一行沒登記的日誌", log("en", "某一行沒登記的日誌"))
        assertEquals("【資料夾同步】全部完成。", log("zh-Hant", "【資料夾同步】全部完成。"))
    }

    @Test
    fun everyPatternHasAllSixLanguages() {
        assertTrue(CoreMessagePatterns.all.size > 250)
        for ((key, _) in CoreMessagePatterns.all) {
            for (tag in listOf("zh-Hant", "en", "zh-Hans", "ja", "ko", "th")) {
                assertNotEquals("$key 缺 $tag", key, LocalizationStrings.localized(key, tag))
            }
        }
    }
}
