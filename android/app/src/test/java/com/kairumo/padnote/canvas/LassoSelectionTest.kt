package com.kairumo.padnote.canvas

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 套索：再製／貼上後選著新的一份、剪下原位貼回、露出圈外的筆畫也拖得到。
 * 與 Apple 端 `LassoSelectionTests` 對應。核心換成記憶體裡的假筆畫（[FakeBackend]）。
 */
class LassoSelectionTest {

    /** 一筆＝一條水平線段，外框就是線段本身（不算筆寬）。 */
    private data class Line(val x0: Float, val y0: Float, val x1: Float, val y1: Float) {
        val bounds get() = Rect(minOf(x0, x1), minOf(y0, y1), maxOf(x0, x1), maxOf(y0, y1))
        fun shifted(dx: Float, dy: Float) = Line(x0 + dx, y0 + dy, x1 + dx, y1 + dy)
    }

    /**
     * 規則與核心一樣「寬容」：線段上取 11 個點，超過一半落在圈的外框裡就算選中 ——
     * 測的是選取狀態機，不是幾何判定（那一份在核心有自己的測試）。
     */
    private class FakeBackend(vararg lines: Line) : LassoBackend {
        val strokes = linkedMapOf<String, Line>()
        private var next = 0

        init { lines.forEach { strokes[newId()] = it } }

        private fun newId() = "s${next++}"

        override fun select(polygon: List<Float>): List<String> {
            val xs = polygon.filterIndexed { i, _ -> i % 2 == 0 }
            val ys = polygon.filterIndexed { i, _ -> i % 2 == 1 }
            val box = Rect(xs.min(), ys.min(), xs.max(), ys.max())
            return strokes.filter { (_, l) ->
                (0..10).count { i ->
                    val t = i / 10f
                    box.contains(Offset(l.x0 + (l.x1 - l.x0) * t, l.y0 + (l.y1 - l.y0) * t))
                } > 5
            }.keys.toList()
        }

        override fun bounds(ids: List<String>): Rect? = ids.mapNotNull { strokes[it]?.bounds }
            .reduceOrNull { a, b ->
                Rect(minOf(a.left, b.left), minOf(a.top, b.top), maxOf(a.right, b.right), maxOf(a.bottom, b.bottom))
            }

        override fun delete(ids: List<String>): Boolean = ids.count { strokes.remove(it) != null } > 0

        override fun copy(ids: List<String>): List<Any> = ids.mapNotNull { strokes[it] }

        override fun paste(clip: List<Any>, dx: Float, dy: Float): List<String> =
            clip.filterIsInstance<Line>().map { line ->
                newId().also { strokes[it] = line.shifted(dx, dy) }
            }

        override fun translate(ids: List<String>, dx: Float, dy: Float): List<String> {
            val copied = copy(ids)
            delete(ids)
            return paste(copied, dx, dy)
        }

        override fun reload() {}
    }

    private fun sample() = FakeBackend(
        Line(100f, 100f, 200f, 100f),
        Line(500f, 500f, 600f, 500f)
    )

    private fun lassoRect(lasso: LassoSelection, r: Rect, backend: LassoBackend) {
        lasso.begin(r.topLeft)
        lasso.extend(r.topRight)
        lasso.extend(r.bottomRight)
        lasso.extend(r.bottomLeft)
        lasso.finish(backend)
    }

    @Test fun duplicateSelectsTheNewCopy() {
        val backend = sample()
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(80f, 80f, 220f, 120f), backend)
        assertEquals(listOf("s0"), lasso.selected)

        assertTrue(lasso.duplicate(backend))
        assertEquals(3, backend.strokes.size)
        // 選著再製出來的那一份，而不是清空選取。
        assertEquals(listOf("s2"), lasso.selected)
        val box = lasso.boundingRect!!
        assertTrue(box.contains(backend.strokes.getValue("s2").bounds.center))

        // 馬上就能拖：在選取框內落下就是拖曳，不是重新圈。
        lasso.begin(box.center)
        assertTrue(lasso.isDragging)
        lasso.extend(box.center + Offset(50f, 30f))
        assertTrue(lasso.finish(backend))
        // 搬的是新的那一份，原本那一份留在原地。
        assertEquals(Line(100f, 100f, 200f, 100f), backend.strokes.getValue("s0"))
        val moved = backend.strokes.getValue(lasso.selected.single())
        assertEquals(100f + LassoSelection.OFFSET + 50f, moved.x0, 0.01f)
        assertEquals(100f + LassoSelection.OFFSET + 30f, moved.y0, 0.01f)
    }

    @Test fun cutThenPasteRestoresInPlaceAndSelects() {
        val backend = sample()
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(80f, 80f, 220f, 120f), backend)
        val original = backend.strokes.getValue("s0")

        assertTrue(lasso.cut(backend))
        assertEquals(1, backend.strokes.size)
        assertFalse(lasso.hasSelection)
        assertTrue("剪下後要有東西可貼", lasso.canPaste)

        assertTrue(lasso.paste(backend))
        assertEquals(2, backend.strokes.size)
        val pasted = backend.strokes.getValue(lasso.selected.single())
        assertEquals(original, pasted)

        // 同一份再貼一次就錯開，不疊在同一個位置。
        assertTrue(lasso.paste(backend))
        val again = backend.strokes.getValue(lasso.selected.single())
        assertEquals(original.x0 + LassoSelection.OFFSET, again.x0, 0.01f)
    }

    @Test fun copyThenPasteIsOffsetAndSelected() {
        val backend = sample()
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(80f, 80f, 220f, 120f), backend)
        lasso.copy(backend)
        assertTrue(lasso.paste(backend))
        assertEquals(3, backend.strokes.size)
        val pasted = backend.strokes.getValue(lasso.selected.single())
        assertEquals(100f + LassoSelection.OFFSET, pasted.x0, 0.01f)
    }

    @Test fun strokePokingOutOfLoopIsDraggable() {
        // 一條長線，圈只圈到大半段。
        val backend = FakeBackend(Line(100f, 100f, 300f, 100f))
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(90f, 80f, 250f, 120f), backend)
        assertTrue(lasso.hasSelection)
        // 在圈外、但在筆畫上的那一段落下 → 要是拖曳，不是重圈（以前會把選取清掉）。
        lasso.begin(Offset(295f, 100f))
        assertTrue(lasso.isDragging)
        assertTrue(lasso.hasSelection)
    }

    @Test fun pressingFarOutsideStartsANewLoop() {
        val backend = sample()
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(80f, 80f, 220f, 120f), backend)
        lasso.begin(Offset(400f, 300f))
        assertFalse(lasso.isDragging)
        assertFalse(lasso.hasSelection)
    }

    // ── 拖曳中筆跡本身跟著走（模擬器實測：原本只有一份藍色預覽在動，原筆跡留在原位）──

    @Test fun dragPreviewFollowsFingerThenClearsOnRelease() {
        val backend = sample()
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(80f, 80f, 220f, 120f), backend)
        val before = lasso.selected.toSet()

        lasso.begin(Offset(150f, 100f))
        lasso.extend(Offset(200f, 130f))
        val preview = lasso.dragPreview()
        // 畫布拿這一份把選中的筆畫畫在位移後的位置；核心此時還沒搬。
        assertEquals(before, preview?.ids)
        assertEquals(Offset(50f, 30f), preview?.offset)
        assertEquals(Line(100f, 100f, 200f, 100f), backend.strokes.values.first())

        assertTrue(lasso.finish(backend))
        // 放開之後核心已經搬好：不能再畫一次位移，否則筆跡會跳到兩倍遠。
        assertEquals(null, lasso.dragPreview())
        assertEquals(Line(150f, 130f, 250f, 130f), backend.strokes.getValue(lasso.selected.single()))
    }

    @Test fun noDragPreviewWhileDrawingTheLoopOrBeforeMoving() {
        val backend = sample()
        val lasso = LassoSelection()
        lasso.begin(Offset(80f, 80f))
        lasso.extend(Offset(220f, 80f))
        assertEquals(null, lasso.dragPreview())
        lasso.extend(Offset(220f, 120f))
        lasso.extend(Offset(80f, 120f))
        lasso.finish(backend)

        // 按在選取上但還沒動：沒有位移，不必讓畫布走預覽那條路。
        lasso.begin(Offset(150f, 100f))
        assertTrue(lasso.isDragging)
        assertEquals(null, lasso.dragPreview())
    }

    @Test fun cancelledDragLeavesStrokesWhereTheyWere() {
        val backend = sample()
        val lasso = LassoSelection()
        lassoRect(lasso, Rect(80f, 80f, 220f, 120f), backend)
        lasso.begin(Offset(150f, 100f))
        lasso.extend(Offset(300f, 300f))
        // 長按叫出飛梭工具盤等情況會取消手勢：預覽要收掉，筆跡不能被搬。
        lasso.cancelGesture()
        assertEquals(null, lasso.dragPreview())
        assertTrue(lasso.hasSelection)
        assertEquals(Line(100f, 100f, 200f, 100f), backend.strokes.values.first())
    }
}
