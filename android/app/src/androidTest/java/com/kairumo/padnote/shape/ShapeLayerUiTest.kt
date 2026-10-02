package com.kairumo.padnote.shape

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithContentDescription
import androidx.compose.ui.test.click
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipe
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.ui.LocalAppLanguage
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiPoint

/**
 * 畫布上的形狀編修（真的算繪、真的手勢）。對應 Apple 端手動在模擬器上驗過的那幾步：
 * 選取之後把手出現、拖縮放把手大小會變、拖連接點拉線、編輯面板即時套用。
 *
 * 手勢測的是**整條路**（命中測試 → 手勢 → 回呼），不是只有算術 —— 把手放在父容器範圍外
 * 的時候算術全對、卻一個都點不到（Compose 的命中測試只把事件交給落在父容器範圍內的子節點）。
 */
@RunWith(AndroidJUnit4::class)
class ShapeLayerUiTest {

    @get:Rule val rule = createComposeRule()

    private fun l(key: String) = LocalizationStrings.localized(key, "en")

    private fun node(id: String, x: Float, y: Float, w: Float = 120f, h: Float = 60f) =
        NoteShape(id = id, kindName = "process", x = x, y = y, width = w, height = h)

    @Test
    fun aSelectedShapeShowsAllItsHandles() {
        rule.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(Modifier.size(600.dp)) {
                    ShapeLayer(
                        interactive = true, shapes = listOf(node("a", 100f, 100f)),
                        connections = emptyList(), density = LocalDensity.current.density,
                        selectedIds = setOf("a"), onSelect = {}, onEdit = {}, onDelete = {},
                        onChanged = {}, zIndexOf = { 0f }, modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
        rule.onAllNodesWithContentDescription(l("resize_shape")).assertCountEquals(8)
        rule.onAllNodesWithContentDescription(l("rotate_handle")).assertCountEquals(1)
        rule.onAllNodesWithContentDescription(l("connection_handle")).assertCountEquals(4)
        rule.onAllNodesWithContentDescription(l("edit")).assertCountEquals(1)
        rule.onAllNodesWithContentDescription(l("delete")).assertCountEquals(1)
    }

    @Test
    fun anUnselectedShapeShowsNoHandles() {
        rule.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(Modifier.size(600.dp)) {
                    ShapeLayer(
                        interactive = true, shapes = listOf(node("a", 100f, 100f)),
                        connections = emptyList(), density = 1f,
                        selectedIds = emptySet(), onSelect = {}, onEdit = {}, onDelete = {},
                        onChanged = {}, zIndexOf = { 0f }, modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
        rule.onAllNodesWithContentDescription(l("resize_shape")).assertCountEquals(0)
    }

    @Test
    fun draggingTheBottomRightHandleGrowsTheShapeAndKeepsTheTopLeftPinned() {
        var shapes by mutableStateOf(listOf(node("a", 100f, 100f)))
        var density = 1f
        rule.setContent {
            density = LocalDensity.current.density
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(Modifier.size(600.dp)) {
                    ShapeLayer(
                        interactive = true, shapes = shapes, connections = emptyList(),
                        density = density, selectedIds = setOf("a"), onSelect = {},
                        onEdit = {}, onDelete = {},
                        onChanged = { u -> shapes = shapes.map { if (it.id == u.id) u else it } },
                        zIndexOf = { 0f }, modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
        // 把手的順序：左上、上、右上、右、右下、下、左下、左 —— 右下是第五顆。
        rule.onAllNodesWithContentDescription(l("resize_shape"))[4].performTouchInput {
            swipe(center, center + Offset(80f * density, 50f * density), durationMillis = 300)
        }
        rule.waitForIdle()
        val resized = shapes.single()
        assertTrue("寬度要變大：${resized.width}", resized.width > 120f + 30f)
        assertTrue("高度要變大：${resized.height}", resized.height > 60f + 15f)
        assertEquals("對面的角（左上）要釘住", 100f, resized.x, 0.5f)
        assertEquals(100f, resized.y, 0.5f)
    }

    @Test
    fun draggingAConnectionHandleReportsTheDragAndTheDrop() {
        val events = mutableListOf<Pair<ShapeAnchor, Boolean>>()
        var density = 1f
        rule.setContent {
            density = LocalDensity.current.density
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(Modifier.size(600.dp)) {
                    ShapeLayer(
                        interactive = true,
                        shapes = listOf(node("a", 100f, 100f), node("b", 100f, 300f)),
                        connections = emptyList(), density = density,
                        selectedIds = setOf("a"), onSelect = {}, onEdit = {}, onDelete = {},
                        onChanged = {}, zIndexOf = { 0f }, modifier = Modifier.fillMaxSize(),
                        onConnectDrag = { _, anchor, _, _, finished -> events += anchor to finished }
                    )
                }
            }
        }
        // 連接點的順序：上、右、下、左 —— 下面那顆（第三顆）往下拖到另一個形狀。
        rule.onAllNodesWithContentDescription(l("connection_handle"))[2].performTouchInput {
            swipe(center, center + Offset(0f, 150f * density), durationMillis = 300)
        }
        rule.waitForIdle()
        assertTrue("拖曳中要回報預覽", events.any { it.first == ShapeAnchor.BOTTOM && !it.second })
        assertTrue("放開要回報", events.any { it.first == ShapeAnchor.BOTTOM && it.second })
    }

    @Test
    fun tappingNearALineSelectsItButEmptySpaceIsNotConsumed() {
        val a = node("a", 100f, 100f)
        val b = node("b", 100f, 300f)
        val link = NoteConnection(
            id = "c", fromShapeId = "a", toShapeId = "b",
            fromAnchor = "bottom", toAnchor = "top", route = "straight")
        var selectedConnection: String? = null
        var parentTaps = 0
        var density = 1f
        rule.setContent {
            density = LocalDensity.current.density
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                Box(
                    Modifier.size(600.dp).pointerInputTap { parentTaps++ }
                ) {
                    ShapeLayer(
                        interactive = true, shapes = listOf(a, b), connections = listOf(link),
                        density = density, selectedIds = emptySet(), onSelect = {}, onEdit = {},
                        onDelete = {}, onChanged = {}, zIndexOf = { 0f },
                        modifier = Modifier.fillMaxSize(),
                        onSelectConnection = { selectedConnection = it }
                    )
                }
            }
        }
        // 線在 x = 160、y 在 160～300 之間。點線上一個點。
        rule.onRoot().performTouchInput { click(Offset(160f * density, 230f * density)) }
        rule.waitForIdle()
        assertEquals("c", selectedConnection)
        assertEquals("點在線上的那一下是連接線的，不該再傳給父層", 0, parentTaps)

        // 點空白處：不能被連接線層吃掉 —— 否則「在空白處點一下新增文字方塊」就再也不會發生。
        // CI 模擬器只有 320dp 寬，不能用 x=330 這種固定畫面座標；點根節點
        // 右下角內縮 20dp，在任何螢幕尺寸都真的落在可點擊的空白區。
        rule.onRoot().performTouchInput {
            click(bottomRight - Offset(20f * density, 20f * density))
        }
        rule.waitForIdle()
        assertTrue("空白處的點擊要傳得到父層", parentTaps >= 1)
    }

    @Test
    fun theEditDialogAppliesEachChangeImmediately() {
        val applied = mutableListOf<NoteShape>()
        var dismissed = false
        rule.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                ShapeEditDialog(
                    shape = node("a", 100f, 100f).apply { label = "x" },
                    languageTag = "en",
                    onApply = { applied += it }, onDuplicate = {}, onDelete = {},
                    onReorder = {}, onDismiss = { dismissed = true }
                )
            }
        }
        rule.onNodeWithText(l("dash_dashed")).performScrollTo().performClick()
        assertEquals("dashed", applied.last().dashStyle)
        // 滾到最上面的那一排也要點得到 —— AlertDialog 的 text 槽是 Box，
        // 拖曳把手若是內容的兄弟就會蓋住內容最上面 24dp（這一條就是為它寫的）。
        rule.onNodeWithText(l("font_bold")).performScrollTo().performClick()
        assertEquals("applied=${applied.map { it.dashStyle to it.isBold }}", true, applied.last().isBold)
        rule.onNodeWithText(l("done")).performClick()
        assertTrue("完成要關得掉", dismissed)
    }

    @Test
    fun theConnectionDialogAppliesAndCanReverse() {
        val applied = mutableListOf<NoteConnection>()
        rule.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                ConnectionEditDialog(
                    link = NoteConnection(id = "c", fromShapeId = "a", toShapeId = "b"),
                    languageTag = "en", onApply = { applied += it }, onDelete = {}, onDismiss = {}
                )
            }
        }
        rule.onNodeWithText(l("route_straight")).performScrollTo().performClick()
        assertEquals("straight", applied.last().route)
        rule.onNodeWithText(l("connection_reverse")).performScrollTo().performClick()
        assertEquals("b", applied.last().fromShapeId)
        assertNotNull(applied.last().startCap)
        assertNull(applied.last().dashStyle)
    }
}

/** 只用來驗「點擊有沒有傳到父層」的小工具。 */
private fun Modifier.pointerInputTap(onTap: () -> Unit): Modifier =
    this.pointerInput(Unit) {
        detectTapGestures { onTap() }
    }
