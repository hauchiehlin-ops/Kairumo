package com.kairumo.padnote.canvas

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.PadnoteSession
import java.io.File

/**
 * 膠帶跨平台格式。Apple 的 `CGRect` 編成 `[[x, y], [w, h]]`；Android 原本只認物件寫法，
 * Apple 建立的膠帶在這裡全落在 (0,0)，而 Android 寫的物件格式 Apple 又解不開。
 * 另外 Android 要把膠帶寫成信封區塊，信封才是讀取時的準 —— 只更新清單的話，移動／縮放會被舊信封蓋回去。
 */
@RunWith(AndroidJUnit4::class)
class NoteTapeCodecTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val pkg get() = File(context.filesDir, "tape-test.padnote")

    @Before
    @After
    fun clean() { pkg.deleteRecursively() }

    @Test
    fun anAppleRectArrayDecodesToItsRealPositionAndSize() {
        val tape = NoteTapeCodec.decode(JSONObject(
            """{"id":"11111111-1111-1111-1111-111111111111","pageIndex":0,"rect":[[10,20],[100,30]],"isRevealed":false,"colorHex":"#FFD1DC"}"""))!!
        assertEquals(10f, tape.x, 0.01f)
        assertEquals(20f, tape.y, 0.01f)
        assertEquals(100f, tape.width, 0.01f)
        assertEquals(30f, tape.height, 0.01f)
    }

    @Test
    fun encodingUsesTheAppleArrayFormat() {
        val obj = NoteTapeCodec.encode(NoteTape(id = "a", pageIndex = 0, x = 5f, y = 6f, width = 70f, height = 32f))
        val rect = obj.getJSONArray("rect")
        assertEquals(5.0, rect.getJSONArray(0).getDouble(0), 0.01)
        assertEquals(70.0, rect.getJSONArray(1).getDouble(0), 0.01)
    }

    @Test
    fun movingATapeUpdatesItsEnvelopeInPlace() {
        PadnoteSession.create(pkg.absolutePath, "T", System.currentTimeMillis().toULong(), 0xC1u)
        val s = PadnoteSession.openExisting(pkg.absolutePath, 0xC1u)
        val page = s.pageIdAt(0u)!!
        val tape = NoteTape(id = "22222222-2222-2222-2222-222222222222", pageIndex = 0, x = 10f, y = 10f, width = 100f, height = 32f)
        NoteTapeCodec.writeEnvelopes(s, page, listOf(tape))
        val blocks = s.imageBlockIds(page).size
        tape.x = 200f; tape.width = 160f
        NoteTapeCodec.writeEnvelopes(s, page, listOf(tape))
        assertEquals("移動不能多長一個區塊", blocks, s.imageBlockIds(page).size)
        val read = s.imageBlockIds(page).mapNotNull {
            NoteTapeCodec.parseEnvelope(s.blockAppearance(it) ?: "", 0)
        }
        assertEquals(1, read.size)
        assertEquals(200f, read[0].x, 0.01f)
        assertEquals(160f, read[0].width, 0.01f)
        NoteTapeCodec.writeEnvelopes(s, page, emptyList())
        assertTrue(s.imageBlockIds(page).mapNotNull { NoteTapeCodec.parseEnvelope(s.blockAppearance(it) ?: "", 0) }.isEmpty())
        s.close()
    }
}
