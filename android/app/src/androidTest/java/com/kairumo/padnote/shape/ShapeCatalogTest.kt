package com.kairumo.padnote.shape

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiShapeCategory
import uniffi.padnote_core.FfiShapeKind
import uniffi.padnote_core.allShapeKinds
import uniffi.padnote_core.flowchartTemplates
import uniffi.padnote_core.shapeCategories
import uniffi.padnote_core.shapeKindsIn

/**
 * 形狀目錄的擴充：立體圖、ISO 5807 補齊、十份範本。對照 Apple 的 `ShapeStudioView`（同一組分組與順序）。
 */
@RunWith(AndroidJUnit4::class)
class ShapeCatalogTest {

    @Test
    fun theCategoriesPartitionEveryKindExactlyOnce() {
        val grouped = shapeCategories().flatMap { shapeKindsIn(it) }
        assertEquals(allShapeKinds().size, grouped.size)
        assertEquals(allShapeKinds().toSet(), grouped.toSet())
        assertTrue(shapeCategories().contains(FfiShapeCategory.SOLID))
        assertEquals(9, shapeKindsIn(FfiShapeCategory.SOLID).size)
    }

    @Test
    fun theNewKindNamesAreTheSamePersistedIdentifiersAsApple() {
        // Kotlin 的列舉名是 ARROW_BLOCK_RIGHT；存檔用的識別字要與 Apple 一致（小寫、無底線），
        // 語系表的鍵才找得到。
        assertEquals("predefinedprocess", NoteShape.nameOf(FfiShapeKind.PREDEFINED_PROCESS))
        assertEquals("triangularprism", NoteShape.nameOf(FfiShapeKind.TRIANGULAR_PRISM))
        assertEquals("arrowblockright", NoteShape.nameOf(FfiShapeKind.ARROW_BLOCK_RIGHT))
        // 舊版 Android 寫過有底線的寫法，仍然認得。
        assertEquals(FfiShapeKind.ROUNDED_RECTANGLE, NoteShape.kindOf("rounded_rectangle"))
        assertEquals(FfiShapeKind.ROUNDED_RECTANGLE, NoteShape.kindOf("roundedrectangle"))
    }

    @Test
    fun aSolidIsInsertedWithAVisibleDepthAndHasFacesToDraw() {
        val cube = NoteShape.inserting(FfiShapeKind.CUBE)
        assertTrue(cube.isSolid)
        assertTrue("立體圖預設深度要看得出來", cube.cornerRadius >= cube.height * 0.2f)
        assertTrue(cube.details().any { it.closed && it.tone < 0f })
        assertFalse(NoteShape.inserting(FfiShapeKind.PROCESS).isSolid)
    }

    @Test
    fun parallelModeOnlyDrawsItsInnerLines() {
        val shape = NoteShape(kindName = "parallelmode", width = 200f, height = 40f)
        assertFalse(shape.drawsOutline)
        assertEquals(2, shape.details().size)
    }

    @Test
    fun thereAreTenTemplatesWithLocalizedNames() {
        val templates = flowchartTemplates()
        assertEquals(10, templates.size)
        for (t in templates) {
            val key = "shape_template_" + t.id.replace('.', '_')
            val text = com.kairumo.padnote.LocalizationStrings.localized(key, "en")
            assertNotNull(text)
            assertTrue("$key 沒有語系字串", text != key)
        }
    }
}
