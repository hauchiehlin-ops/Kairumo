package com.kairumo.padnote.ink

import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 觸控筆側鍵 → 橡皮擦的對應規則（工作項 S-67，Android 端）。
 *
 * **側鍵事件本身在這裡驗不到** —— 要實體觸控筆才發得出 `buttonState`，
 * 模擬器沒有，`adb input` 也送不出來（實機行為列 S-40）。能驗的是「收到
 * 之後要做什麼」，而那正是會寫錯的地方：切過去容易，放開要回到哪支筆、
 * 以及**什麼時候不該動**才是真正的判斷。
 *
 * Apple 端的對照組是 `PencilDoubleTapTests.swift`，規則刻意一致。
 */
@RunWith(AndroidJUnit4::class)
class StylusButtonTest {

    @Test
    fun plainStylusIsNotErasing() {
        assertFalse(StylusButton.isErasing(MotionEvent.TOOL_TYPE_STYLUS, 0))
    }

    @Test
    fun barrelButtonErases() {
        assertTrue(
            StylusButton.isErasing(
                MotionEvent.TOOL_TYPE_STYLUS, MotionEvent.BUTTON_STYLUS_PRIMARY))
    }

    @Test
    fun invertedPenErases() {
        // S Pen 與 Surface Pen 倒過來用會直接回報 ERASER，沒有按任何鍵。
        assertTrue(StylusButton.isErasing(MotionEvent.TOOL_TYPE_ERASER, 0))
    }

    @Test
    fun otherButtonsAreNotTheEraserButton() {
        // 側鍵有兩顆的筆，第二顆不是橡皮擦 —— 拿它來擦的話，
        // 使用者按下去想做的事（通常是右鍵／選取）會變成擦掉東西。
        assertFalse(
            StylusButton.isErasing(
                MotionEvent.TOOL_TYPE_STYLUS, MotionEvent.BUTTON_STYLUS_SECONDARY))
    }

    @Test
    fun pressingSwitchesToEraser() {
        assertEquals(
            InkTool.ERASER,
            StylusButton.outcome(true, InkTool.HIGHLIGHTER, InkTool.HIGHLIGHTER))
    }

    @Test
    fun releasingComesBackToTheLastBrushNotTheDefaultPen() {
        // 用鉛筆的人每擦一次都被換回鋼筆的話，這個手勢會比不做還糟。
        assertEquals(
            InkTool.PENCIL,
            StylusButton.outcome(false, InkTool.ERASER, InkTool.PENCIL))
    }

    @Test
    fun holdingItDownDoesNotKeepReSwitching() {
        // 已經是橡皮擦了就回 null。每個 ACTION_MOVE 都重設一次工具的話，
        // 一次書寫會把上層狀態寫上百次。
        assertNull(StylusButton.outcome(true, InkTool.ERASER, InkTool.PENCIL))
    }

    @Test
    fun notErasingAndNotOnTheEraserChangesNothing() {
        assertNull(StylusButton.outcome(false, InkTool.BALLPOINT, InkTool.BALLPOINT))
    }

    @Test
    fun aNonBrushLastToolNeverMakesTheSwitchANoOp() {
        // 呼叫端理論上不會這樣傳，但真的傳了的話，放開側鍵不能還是橡皮擦
        // —— 那會讓使用者以為筆卡住了。
        for (stale in listOf(InkTool.ERASER, InkTool.LASSO)) {
            assertEquals(
                "lastBrush = $stale",
                InkTool.FOUNTAIN_PEN,
                StylusButton.outcome(false, InkTool.ERASER, stale))
        }
    }

    @Test
    fun everyBrushCanBeReturnedTo() {
        // 新增一支筆卻忘了給它 `kind`，症狀是「用那支筆時擦完回不去」。
        for (tool in InkTool.entries.filter { it.kind != null }) {
            assertEquals(
                "$tool 切不回去",
                tool,
                StylusButton.outcome(false, InkTool.ERASER, tool))
        }
    }
}
