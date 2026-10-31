package com.kairumo.padnote.canvas

import com.kairumo.padnote.text.TextBox
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 全域復原：筆跡與物件在同一條時間軸上。與 Apple 端 `CanvasHistoryTests` 逐項對應。
 */
class CanvasHistoryTest {

    private var now = 0L
    private val history = CanvasHistory { now }
    private var page = CanvasSnapshot(texts = listOf(TextBox(id = "t1", text = "", x = 10f)))
    private var strokes = 0

    private fun change(edit: (CanvasSnapshot) -> CanvasSnapshot) {
        page = edit(page)
        history.observe(page)
    }

    private fun moveText(x: Float) = change { s -> s.copy(texts = s.texts.map { it.copy(x = x) }) }
    private fun undo() = history.undo({ page = it }) { if (strokes > 0) { strokes--; true } else false }
    private fun redo() = history.redo({ page = it }) { strokes++; true }
    private fun drawStroke() { strokes++; history.inkCommitted() }

    init { history.reset(page) }

    @Test fun movingAnObjectIsUndoableAndRedoable() {
        moveText(200f)
        assertTrue(undo())
        assertEquals(10f, page.texts[0].x, 0.001f)
        assertTrue(redo())
        assertEquals(200f, page.texts[0].x, 0.001f)
    }

    @Test fun objectAndInkStepsUndoInOrder() {
        drawStroke()
        now += 5000
        moveText(99f)
        drawStroke()
        undo()
        assertEquals(1, strokes)
        assertEquals(99f, page.texts[0].x, 0.001f)
        undo()
        assertEquals(10f, page.texts[0].x, 0.001f)
        assertEquals(1, strokes)
        undo()
        assertEquals(0, strokes)
        assertFalse(history.canUndo)
    }

    @Test fun typingInOneBoxBecomesOneStep() {
        for (t in listOf("H", "He", "Hel", "Hello")) {
            now += 100
            change { s -> s.copy(texts = s.texts.map { it.copy(text = t) }) }
        }
        undo()
        assertEquals("", page.texts[0].text)
        assertFalse(history.canUndo)
    }

    @Test fun changesFarApartInTimeAreSeparateSteps() {
        moveText(20f)
        now += 5000
        moveText(30f)
        undo()
        assertEquals(20f, page.texts[0].x, 0.001f)
    }

    @Test fun deletingAndRestoringAnObject() {
        change { s -> s.copy(texts = emptyList()) }
        undo()
        assertEquals(listOf("t1"), page.texts.map { it.id })
    }

    @Test fun aNewChangeClearsRedo() {
        moveText(1f)
        undo()
        now += 5000
        change { s -> s.copy(order = listOf("t1")) }
        assertFalse(history.canRedo)
    }

    @Test fun reloadingIsNotAStep() {
        // 讀進來（或別台同步進來）的內容是基準，不是「新增了所有物件」。
        val loaded = CanvasSnapshot(texts = listOf(TextBox(id = "a"), TextBox(id = "b")))
        history.reset(loaded)
        history.observe(loaded)
        assertFalse(history.canUndo)
    }

    @Test fun snapshotsAreIndependentOfLaterInPlaceEdits() {
        // 物件拖曳時是就地改的；快照若共用實例，「改之前」那份會跟著變。
        val live = TextBox(id = "x", x = 1f)
        history.reset(CanvasSnapshot(texts = listOf(live.copy())))
        live.x = 50f
        history.observe(CanvasSnapshot(texts = listOf(live.copy())))
        var restored: CanvasSnapshot? = null
        history.undo({ restored = it }) { false }
        assertEquals(1f, restored!!.texts[0].x, 0.001f)
    }

    @Test fun insertingThenRaisingToTopIsOneStep() {
        // 插入物件之後，App 會把它放到最上層（只改順序）。那不是另一個動作。
        change { s -> s.copy(texts = s.texts + TextBox(id = "t2")) }
        now += 200
        change { s -> s.copy(order = listOf("t1", "t2")) }
        undo()
        assertEquals(listOf("t1"), page.texts.map { it.id })
        assertEquals(emptyList<String>(), page.order)
        assertFalse(history.canUndo)
    }

    @Test fun continuousModeUndoesAcrossPagesInOrder() {
        // 第 3 頁畫一筆 → 第 5 頁搬文字 → 第 3 頁再畫一筆：復原依序回第 3、第 5、第 3 頁。
        val paged = CanvasHistory { now }
        val p5 = CanvasSnapshot(texts = listOf(TextBox(id = "x", x = 1f)))
        paged.reset(CanvasSnapshot(), "p3")
        paged.reset(p5, "p5")
        paged.inkCommitted("p3")
        now += 5000
        paged.observe(CanvasSnapshot(texts = listOf(TextBox(id = "x", x = 90f))), "p5")
        paged.inkCommitted("p3")

        val visited = mutableListOf<String>()
        var restored: CanvasSnapshot? = null
        repeat(3) {
            paged.undoAcrossPages(
                applyObjects = { pageId, snapshot -> visited += pageId; restored = snapshot },
                undoInk = { pageId -> visited += pageId; true }
            )
        }
        assertEquals(listOf("p3", "p5", "p3"), visited)
        assertEquals(1f, restored!!.texts[0].x, 0.001f)
        assertFalse(paged.canUndo)
    }

    @Test fun tapeOperationsAreUndoableAndRedoable() {
        val tape1 = NoteTape(id = "tape-1", pageIndex = 0, x = 10f, y = 20f, width = 120f, height = 30f)
        now += 5000
        change { s -> s.copy(tapes = listOf(tape1)) }
        assertEquals(1, page.tapes.size)

        // 揭開膠帶（reveal）
        now += 5000
        change { s -> s.copy(tapes = listOf(tape1.copy(isRevealed = true))) }
        assertTrue(page.tapes[0].isRevealed)

        // 復原翻開狀態
        assertTrue(undo())
        assertFalse(page.tapes[0].isRevealed)

        // 復原新增膠帶
        assertTrue(undo())
        assertTrue(page.tapes.isEmpty())

        // 重做新增膠帶
        assertTrue(redo())
        assertEquals(1, page.tapes.size)
        assertFalse(page.tapes[0].isRevealed)

        // 重做揭開膠帶
        assertTrue(redo())
        assertTrue(page.tapes[0].isRevealed)
    }

    @Test fun changesOnDifferentPagesAreNeverMerged() {
        val paged = CanvasHistory { now }
        paged.reset(CanvasSnapshot(texts = listOf(TextBox(id = "x"))), "a")
        paged.reset(CanvasSnapshot(texts = listOf(TextBox(id = "x"))), "b")
        paged.observe(CanvasSnapshot(texts = listOf(TextBox(id = "x", text = "1"))), "a")
        paged.observe(CanvasSnapshot(texts = listOf(TextBox(id = "x", text = "1"))), "b")
        var steps = 0
        while (paged.undoAcrossPages({ _, _ -> steps++ }, { true })) Unit
        assertEquals(2, steps)
    }
}
