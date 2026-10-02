package com.kairumo.padnote.audio

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.image.LinkLayer
import com.kairumo.padnote.image.LinkObject
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeLayer
import com.kairumo.padnote.ui.LocalAppLanguage
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 互動矩陣（驗證層 L2）Android 版的其餘物件：連結卡片與形狀，選取後刪除鈕點得動。
 * 與 Apple 的 `InteractionMatrixAudit` 同一個問題：「畫得出來」不等於「按得到」。
 */
@RunWith(AndroidJUnit4::class)
class ObjectLayersInteractionTest {

    @get:Rule
    val compose = createComposeRule()

    private val density get() = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density

    @Test
    fun linkCardDeleteReachesItsCallback() {
        var deletes = 0
        compose.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(Modifier.size(600.dp, 400.dp)) {
                    LinkLayer(
                        interactive = true,
                        links = listOf(LinkObject("l1", 0, "https://example.com", "T", "", "", 60f, 60f, 300f, 100f)),
                        density = density, selectedId = "l1", onSelect = {}, onOpen = {}, onEdit = {},
                        onDelete = { deletes++ }, onChanged = {}, zIndexOf = { 0f }
                    )
                }
            }
        }
        compose.onNodeWithTag("link.card.delete").performClick()
        compose.runOnIdle { assertEquals("連結卡片的刪除鈕點下去沒有呼叫刪除", 1, deletes) }
    }

    @Test
    fun shapeDeleteReachesItsCallback() {
        var deletes = 0
        val shape = NoteShape(id = "s1", x = 80f, y = 80f, width = 160f, height = 80f)
        compose.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(Modifier.size(600.dp, 400.dp)) {
                    ShapeLayer(
                        interactive = true, shapes = listOf(shape), connections = emptyList(), density = density,
                        selectedIds = setOf("s1"), onSelect = {}, onEdit = {}, onDelete = { deletes++ },
                        onChanged = {}, zIndexOf = { 0f }
                    )
                }
            }
        }
        compose.onNodeWithContentDescription(LocalizationStrings.localized("delete", "en")).performClick()
        compose.runOnIdle { assertEquals("形狀的刪除鈕點下去沒有呼叫刪除", 1, deletes) }
    }
}
