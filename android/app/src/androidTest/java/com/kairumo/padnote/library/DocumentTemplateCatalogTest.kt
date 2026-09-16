package com.kairumo.padnote.library

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.text.TextBoxStore
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/**
 * 文件範本目錄（工作項 S-61）。
 *
 * 與 Apple 端的 `DocumentTemplateTests` 是同一組檢查、同一份資料。
 * 兩邊都驗的理由是：資源沒被打包時目錄會**安靜地**變成空清單，
 * 畫面上只是少一段內容，不會報錯。
 */
@RunWith(AndroidJUnit4::class)
class DocumentTemplateCatalogTest {

    private val context = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun theCatalogIsActuallyBundled() {
        assertFalse(
            "目錄是空的 —— 多半是 Gradle 沒把 templates/ 複製進 assets，" +
                "而那不會報錯，只會讓範本清單整個消失",
            DocumentTemplateCatalog.themes(context).isEmpty()
        )
    }

    @Test
    fun everyTemplateHasBothVariantsAndSixLanguageNames() {
        for (theme in DocumentTemplateCatalog.themes(context)) {
            for (category in theme.categories) {
                for (tmpl in category.templates) {
                    for (kind in DocumentTemplateCatalog.VariantKind.entries) {
                        val variant = DocumentTemplateCatalog.variant(tmpl, kind, "zhHant")
                        assertNotNull("${tmpl.id} 缺 ${kind.key} 版本", variant)
                        assertFalse(
                            "${tmpl.id} 的 ${kind.key} 版本沒有任何內容",
                            variant!!.blocks.isEmpty()
                        )
                    }
                    for (lang in listOf("zhHant", "en", "zhHans", "ja", "ko", "th")) {
                        assertTrue(
                            "${tmpl.id} 缺 $lang 的名稱",
                            DocumentTemplateCatalog.localized(tmpl.name, lang).isNotEmpty()
                        )
                    }
                }
            }
        }
    }

    @Test
    fun blocksStayInsideThePageAndTablesAreWellFormed() {
        // 版面是產生器算的。算錯的話文字會掉到紙外面 —— 畫面上看不出來，
        // 但列印或匯出時那一段就是不見了。
        for (theme in DocumentTemplateCatalog.themes(context)) {
            for (category in theme.categories) {
                for (tmpl in category.templates) {
                    for (kind in DocumentTemplateCatalog.VariantKind.entries) {
                        val variant =
                            DocumentTemplateCatalog.variant(tmpl, kind, "zhHant") ?: continue
                        for (b in variant.blocks) {
                            assertTrue("${tmpl.id} 區塊超出紙張右緣", b.x + b.width <= PAGE_W)
                            assertTrue("${tmpl.id} 區塊超出紙張下緣", b.y + b.height <= PAGE_H)
                            assertTrue("${tmpl.id} 區塊指到不存在的頁", b.page < variant.pageCount)
                            if (b.kind == "table") {
                                assertEquals(
                                    "${tmpl.id} 的表格格數與列欄數對不上",
                                    b.rows * b.cols, b.cells.size
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    @Test
    fun applyingATemplatePutsContentOnThePage() {
        val tmpl = DocumentTemplateCatalog.template(context, "meeting_minutes")
        assertNotNull("找不到會議紀錄範本", tmpl)

        val dir = File(context.cacheDir, "tmpl-${System.nanoTime()}")
        val id = NotebookLibrary.create(context, "範本測試", 0xC0u, null)
        assertNotNull("建不出筆記本", id)
        val opened = NotebookLibrary.open(context, id!!, 0xC0u)
        assertNotNull("開不了剛建的筆記本", opened)
        val (session, page) = opened!!

        val ok = DocumentTemplateCatalog.apply(
            session, page, tmpl!!, DocumentTemplateCatalog.VariantKind.EXAMPLE, "zhHant"
        )
        assertTrue("套用失敗", ok)

        val store = TextBoxStore(session, page)
        store.load()
        assertFalse("套用後第一頁應該有文字區塊", store.all.isEmpty())
        dir.deleteRecursively()
    }

    private companion object {
        // 與核心的 `standard_page_size` 一致。
        const val PAGE_W = 800f
        const val PAGE_H = 1132f
    }
}
