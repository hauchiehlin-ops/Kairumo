package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 預載的《Kairumo手冊》：全部是手繪筆畫（沒有文字方塊、形狀、圖片）。
 * 全新安裝要有；舊使用者只補一次，刪掉之後不再長回來。
 */
@RunWith(AndroidJUnit4::class)
class KairumoManualSeedTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val device = 0xE7u

    @Before
    @After
    fun clean() {
        File(context.filesDir, "Notebooks").deleteRecursively()
        context.getSharedPreferences("kairumo.seed", android.content.Context.MODE_PRIVATE).edit().clear().commit()
    }

    private fun manual() = NotebookLibrary.all(context, device).firstOrNull { it.title == "Kairumo手冊" }

    @Test
    fun aFreshInstallGetsTheManualMadeOfInkOnly() {
        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")
        val entry = assertNotNull(manual()).let { manual()!! }
        val (session, _) = NotebookLibrary.open(context, entry.id, device)!!
        assertEquals(4, session.pageCount().toInt())
        for (index in 0 until 4) {
            val page = session.pageIdAt(index.toUInt())!!
            assertTrue("第 ${index + 1} 頁的筆畫太少", session.visibleStrokes(page).size > 100)
            // 只有筆畫：不能有文字、表格、圖片區塊。
            assertTrue(session.textBlockIds(page).isEmpty())
            assertTrue(session.tableBlockIds(page).isEmpty())
            assertTrue(session.imageBlockIds(page).isEmpty())
        }
    }

    @Test
    fun theStrokeDataLicenceTravelsWithTheApp() {
        // 筆順資料來自 Arphic 字型（Arphic Public License）：授權全文要隨 App 一起散布。
        for (name in listOf("seed/ARPHICPL.TXT", "seed/NOTICE.txt", "seed/OFL-NotoSansThai.txt")) {
            val text = context.assets.open(name).bufferedReader().use { it.readText() }
            assertTrue("$name 是空的", text.isNotBlank())
        }
        val licence = context.assets.open("seed/ARPHICPL.TXT").bufferedReader().use { it.readText() }
        assertTrue(licence.contains("ARPHIC PUBLIC LICENSE"))
    }

    @Test
    fun anExistingLibraryGetsItOnceAndDeletingItSticks() {
        NotebookLibrary.create(context, "我的筆記", device)
        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")
        assertNotNull(manual())
        manual()!!.let { NotebookLibrary.delete(context, it.id) }
        SeedNotebooks.seedIfEmpty(context, device, "zh-Hant")
        assertTrue("刪掉的手冊不該自己長回來", manual() == null)
    }
}
