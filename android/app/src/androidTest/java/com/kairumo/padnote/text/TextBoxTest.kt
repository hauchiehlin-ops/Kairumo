package com.kairumo.padnote.text

import androidx.compose.ui.graphics.Color
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * Android 的文字方塊（與 Apple 端同一組規則）。
 *
 * 重點不是「能不能顯示」，而是**兩個平台對同一份資料算出同樣的結果** ——
 * 顏色、透明、段落、編碼鍵名。不一致的話，使用者在 iPad 上設好的方塊
 * 換到 Android 會變個樣，而那種不一致只有他會發現。
 */
@RunWith(AndroidJUnit4::class)
class TextBoxTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    private fun session(name: String): Pair<PadnoteSession, String> {
        val dir = File(context.cacheDir, "tb-$name-${System.nanoTime()}")
        val s = PadnoteSession.create(dir.absolutePath, "文字方塊", 1_757_635_200_000uL, 0xF1u)
        return s to s.firstPageId()!!
    }

    // MARK: - 透明

    @Test
    fun clearIsTransparentNotWhite() {
        // "clear" 是哨符不是顏色。走 hex 轉換的話 alpha 會被丟掉變成黑色 ——
        // Apple 端就是這樣出過一次 bug。
        val box = TextBox(id = "a", backgroundColorHex = "clear")
        assertEquals(Color.Transparent, resolveBackground(box))
        assertTrue(box.isBackgroundClear)
    }

    @Test
    fun nullBackgroundFallsBackToTheDefaultNotTransparent() {
        // null（舊資料沒設定）與 "clear"（使用者主動選透明）是兩回事。
        assertEquals(Color.White, resolveBackground(TextBox(id = "a", backgroundColorHex = null)))
    }

    @Test
    fun anInvalidColorFallsBackInsteadOfDisappearing() {
        assertNotEquals(
            Color.Transparent,
            resolveBackground(TextBox(id = "a", backgroundColorHex = "不是顏色"))
        )
    }

    // MARK: - 編碼（跨平台的關鍵）

    @Test
    fun appearanceRoundTripsThroughJson() {
        val original = TextBox(
            id = "a", fontSize = 22f, bold = true, alignment = "center",
            textColorHex = "#112233", backgroundColorHex = "clear",
            hasBorder = false, borderWidth = 3f, cornerRadius = 20f,
            width = 420f, height = 260f,
            lineSpacing = 8f, paragraphSpacing = 16f,
            firstLineIndent = 24f, paragraphIndent = 32f
        )
        val restored = TextBox(id = "a")
        TextBoxAppearance.apply(TextBoxAppearance.encode(original), restored)

        assertEquals(original.fontSize, restored.fontSize)
        assertEquals(original.bold, restored.bold)
        assertEquals(original.alignment, restored.alignment)
        assertEquals(original.backgroundColorHex, restored.backgroundColorHex)
        assertEquals(original.hasBorder, restored.hasBorder)
        assertEquals(original.lineSpacing, restored.lineSpacing)
        assertEquals(original.paragraphIndent, restored.paragraphIndent)
        assertEquals(original.width, restored.width)
    }

    @Test
    fun unsetFieldsAreNotWrittenIntoTheJson() {
        // null 寫成 0 的話，接收端就分不出「沒設定」與「設成 0」——
        // 於是每一個從另一個平台來的方塊都會被當成「行距 0」。
        val json = TextBoxAppearance.encode(TextBox(id = "a"))
        assertTrue("沒設定的行距不該出現在 JSON 裡", !json.contains("lineSpacing"))
        assertTrue(!json.contains("paragraphSpacing"))
        assertTrue(!json.contains("borderWidth"))
    }

    @Test
    fun unknownKeysAreIgnoredNotFatal() {
        // 另一個平台可能帶了我們還沒實作的欄位。該做的是保留其餘設定。
        val box = TextBox(id = "a")
        TextBoxAppearance.apply("""{"fontSize":30,"somethingFromTheFuture":{"a":1}}""", box)
        assertEquals(30f, box.fontSize)
    }

    @Test
    fun malformedJsonLeavesTheBoxUntouched() {
        val box = TextBox(id = "a", fontSize = 16f)
        TextBoxAppearance.apply("這不是 JSON", box)
        assertEquals(16f, box.fontSize)
    }

    // MARK: - 持久化

    @Test
    fun aTextBoxSurvivesReopeningTheNotebook() {
        // 文字、位置、外觀三樣都要寫回核心 —— 少一樣就有東西跨不過平台。
        val dir = File(context.cacheDir, "tb-persist-${System.nanoTime()}")
        run {
            val s = PadnoteSession.create(dir.absolutePath, "持久", 1_757_635_200_000uL, 0xF2u)
            val store = TextBoxStore(s, s.firstPageId()!!)
            val created = store.create(x = 120f, y = 240f)
            created.text = "會議重點"
            created.backgroundColorHex = "clear"
            created.lineSpacing = 8f
            store.persist(created)
        }

        val reopened = PadnoteSession.openExisting(dir.absolutePath, 0xF3u)
        val store = TextBoxStore(reopened, reopened.firstPageId()!!)
        store.load()

        assertEquals(1, store.all.size)
        val box = store.all.first()
        assertEquals("會議重點", box.text)
        assertEquals(120f, box.x)
        assertEquals(240f, box.y)
        assertEquals("clear", box.backgroundColorHex)
        assertEquals(8f, box.lineSpacing)
    }

    @Test
    fun onlyTextBlocksAreListed() {
        // 圖片也是區塊。混進來的話畫面上會出現空白的文字方塊。
        val (s, page) = session("mixed")
        val store = TextBoxStore(s, page)
        store.create(10f, 10f)
        val blob = s.putBlob(byteArrayOf(1, 2, 3))
        s.addImage(page, blob, 10f, 10f)

        store.load()
        assertEquals(1, store.all.size)
    }

    @Test
    fun aDeletedBoxDoesNotComeBack() {
        val (s, page) = session("delete")
        val store = TextBoxStore(s, page)
        store.remove(store.create(10f, 10f))
        store.load()
        assertTrue(store.all.isEmpty())
    }

    @Test
    fun aStoreWithoutACoreSessionStillWorks() {
        // 核心開不起來時 UI 不該整個垮掉 —— 退成只活在記憶體裡的方塊。
        val store = TextBoxStore(null, null)
        assertEquals(10f, store.create(10f, 20f).x)
        assertEquals(1, store.all.size)
    }

    // MARK: - 與 Apple 的一致性

    @Test
    fun thePaddingMatchesTheOtherPlatform() {
        // 內距差幾點就會讓同一段文字在兩個平台換行位置不同，版面就分家了。
        assertEquals(14f, TEXT_BOX_PADDING)
    }
}
