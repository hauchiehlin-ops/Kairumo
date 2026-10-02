package com.kairumo.padnote.shape

import com.kairumo.padnote.canvas.ObjectStacking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import uniffi.padnote_core.FfiPoint
import kotlin.math.hypot

/**
 * 形狀編修的算術：縮放把手、線段端點、連接線欄位的來回、單物件的層級動作。
 *
 * 手指到數字的換算錯了不會跳例外，只會讓東西**往錯的方向長**：轉過 90° 的方塊拖右邊，
 * 卻是上面那條邊在動；拖完線的端點，線跑到別處。每一條都盯著「使用者最後看到什麼」，
 * 而且與 Apple 端 `ShapeEditingTests` 逐項對應 —— 兩邊的換算不同的話，同一個形狀在
 * 兩台裝置上拖出來的結果就不一樣。
 */
class ShapeFrameMathTest {

    private val frame = ShapeFrameMath.Frame(100f, 100f, 200f, 100f)

    @Test fun draggingTheRightEdgeGrowsWidthAndPinsTheLeftEdge() {
        val r = ShapeFrameMath.resized(frame, 0f, sx = 1f, sy = 0f, localDx = 40f, localDy = 999f)
        assertEquals(100f, r.x, 0.001f)
        assertEquals(240f, r.width, 0.001f)
        assertEquals(100f, r.height, 0.001f) // 邊中點的把手不能動到另一個軸
    }

    @Test fun draggingTheTopLeftCornerMovesBothAxes() {
        val r = ShapeFrameMath.resized(frame, 0f, sx = -1f, sy = -1f, localDx = -20f, localDy = -10f)
        assertEquals(300f, r.x + r.width, 0.001f)
        assertEquals(200f, r.y + r.height, 0.001f)
        assertEquals(220f, r.width, 0.001f)
        assertEquals(110f, r.height, 0.001f)
    }

    @Test fun rotatedShapePinsTheOppositeEdgeOnTheCanvas() {
        // 轉 90°，拖形狀自己的「右」邊：畫布上「左邊」那條邊的位置不能變。
        val r = ShapeFrameMath.resized(frame, 90f, sx = 1f, sy = 0f, localDx = 30f, localDy = 0f)
        assertEquals(230f, r.width, 0.01f)
        val before = ShapeFrameMath.rotate(
            FfiPoint(frame.x, frame.centerY), FfiPoint(frame.centerX, frame.centerY), 90.0)
        val after = ShapeFrameMath.rotate(
            FfiPoint(r.x, r.centerY), FfiPoint(r.centerX, r.centerY), 90.0)
        assertEquals(before.x, after.x, 0.01f)
        assertEquals(before.y, after.y, 0.01f)
    }

    @Test fun resizeNeverGoesBelowTheMinimumSide() {
        val r = ShapeFrameMath.resized(frame, 0f, 1f, 1f, -9999f, -9999f)
        assertEquals(ShapeFrameMath.MIN_SIDE, r.width, 0f)
        assertEquals(ShapeFrameMath.MIN_SIDE, r.height, 0f)
    }

    @Test fun lineFrameRoundTripsArbitraryEndpoints() {
        val cases = listOf(
            listOf(50f, 50f, 250f, 120f),
            listOf(250f, 120f, 50f, 50f),   // 反向
            listOf(100f, 300f, 100f, 40f),  // 垂直向上
            listOf(10f, 10f, 400f, 10f),    // 水平
            listOf(300f, 300f, 120f, 480f)  // 左下
        )
        for ((ax, ay, bx, by) in cases) {
            val (f, deg) = ShapeFrameMath.lineFrame(ax, ay, bx, by)
            val line = NoteShape(
                kindName = "line", x = f.x, y = f.y, width = f.width, height = f.height,
                rotationDegrees = deg
            )
            // 端點 = 外框對角線的兩端，繞中心轉 deg（不經過核心，直接用同一個公式驗）。
            val c = FfiPoint(f.centerX, f.centerY)
            val s = ShapeFrameMath.rotate(FfiPoint(f.x, f.y), c, deg.toDouble())
            val e = ShapeFrameMath.rotate(FfiPoint(f.x + f.width, f.y + f.height), c, deg.toDouble())
            assertEquals("$ax,$ay 起點 x", ax, s.x, 0.1f)
            assertEquals("$ax,$ay 起點 y", ay, s.y, 0.1f)
            assertEquals("$ax,$ay 終點 x", bx, e.x, 0.1f)
            assertEquals("$ax,$ay 終點 y", by, e.y, 0.1f)
            assertTrue(hypot(bx - ax, by - ay) > 0f && line.width > 0f)
        }
    }

    @Test fun snappingOnlyHappensNearAMultiple() {
        assertEquals(45f, ShapeFrameMath.snapped(44f), 0f)
        assertEquals(38f, ShapeFrameMath.snapped(38f), 0f)
    }

    // ---- 連接線欄位 ----

    @Test fun reverseSwapsEndsAnchorsAndCaps() {
        val c = NoteConnection(fromShapeId = "a", toShapeId = "b", fromAnchor = "bottom", toAnchor = "top").reversed()
        assertEquals("b", c.fromShapeId)
        assertEquals("top", c.fromAnchor)
        // 預設的「終點箭頭」要跟著到新的終點。
        assertEquals(ConnectionCap.ARROW, c.startCapName)
        assertEquals(ConnectionCap.NONE, c.endCapName)
    }

    // ---- 單物件的層級動作 ----

    @Test fun reorderOpsMatchTheStackingFunctions() {
        val order = listOf("a", "b", "c", "d")
        assertEquals(listOf("a", "c", "d", "b"), ObjectStacking.Reorder.TO_FRONT.apply("b", order))
        assertEquals(listOf("c", "a", "b", "d"), ObjectStacking.Reorder.TO_BACK.apply("c", order))
        assertEquals(listOf("a", "c", "b", "d"), ObjectStacking.Reorder.FORWARD.apply("b", order))
        assertEquals(listOf("b", "a", "c", "d"), ObjectStacking.Reorder.BACKWARD.apply("b", order))
        assertEquals(order, ObjectStacking.Reorder.FORWARD.apply("d", order)) // 已在最上層
    }

    @Test fun newObjectsGoOnTopOfEverythingIncludingLaterKinds() {
        // 沒有明確順序時，圖片（預設層級 0）會在既有的文字（6）之下 —— 新插入的要在最上面。
        val existing = listOf(
            ObjectStacking.Item("t", ObjectStacking.Kind.TEXT, ""),
            ObjectStacking.Item("s", ObjectStacking.Kind.SHAPE, "")
        )
        val order = ObjectStacking.withNewOnTop(existing, emptyList(), listOf("img"))
        assertEquals("img", order.last())
        assertTrue(order.indexOf("img") > order.indexOf("t"))
    }
}
