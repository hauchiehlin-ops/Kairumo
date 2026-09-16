package com.kairumo.padnote.ink

import android.view.MotionEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiPenControl
import uniffi.padnote_core.FfiPenOutcome
import uniffi.padnote_core.PenControls

/**
 * 筆身控制項在 Android 這一側的接線（工作項 S-40 / S-67）。
 *
 * **對應規則本身不在這裡驗** —— 它在核心的 `padnote-input::pen`，有 11 條
 * Rust 測試，而且 Apple 端走的是同一份。這裡驗的是 Android 這一側真正會
 * 出錯的兩件事：`MotionEvent` 上的位元翻得對不對，以及設定存不存得回來。
 *
 * `buttonState` 要實體觸控筆才發得出來（模擬器沒有，`adb input` 也送不出），
 * 實機行為列 S-40 / A-14。
 */
@RunWith(AndroidJUnit4::class)
class PenHardwareTest {

    @Test
    fun aPlainStylusIsNotAnyControl() {
        assertNull(PenHardware.control(MotionEvent.TOOL_TYPE_STYLUS, 0))
    }

    @Test
    fun theBarrelButtonsMapToTheRightControls() {
        assertEquals(
            FfiPenControl.BARREL_PRIMARY,
            PenHardware.control(MotionEvent.TOOL_TYPE_STYLUS, MotionEvent.BUTTON_STYLUS_PRIMARY))
        assertEquals(
            FfiPenControl.BARREL_SECONDARY,
            PenHardware.control(MotionEvent.TOOL_TYPE_STYLUS, MotionEvent.BUTTON_STYLUS_SECONDARY))
    }

    @Test
    fun turningThePenOverIsItsOwnControl() {
        // S Pen 與 Surface Pen 倒過來用會直接回報 ERASER，沒有按任何鍵。
        assertEquals(
            FfiPenControl.INVERT,
            PenHardware.control(MotionEvent.TOOL_TYPE_ERASER, 0))
    }

    @Test
    fun turningThePenOverWinsOverASideButton() {
        // 筆倒過來的時候，就算側鍵也按著，使用者要的也是擦。
        assertEquals(
            FfiPenControl.INVERT,
            PenHardware.control(
                MotionEvent.TOOL_TYPE_ERASER, MotionEvent.BUTTON_STYLUS_PRIMARY))
    }

    @Test
    fun onlyOneControlIsReportedAtATime() {
        // 兩顆鍵同時按著是誤觸，不是一個有意義的組合。兩個都處理的話，
        // 工具會在兩種狀態之間跳。
        val both = MotionEvent.BUTTON_STYLUS_PRIMARY or MotionEvent.BUTTON_STYLUS_SECONDARY
        assertEquals(
            FfiPenControl.BARREL_PRIMARY,
            PenHardware.control(MotionEvent.TOOL_TYPE_STYLUS, both))
    }

    @Test
    fun anOrdinaryMouseButtonIsNotAPenControl() {
        // 接滑鼠的人按左鍵不該切成橡皮擦。
        assertNull(
            PenHardware.control(MotionEvent.TOOL_TYPE_MOUSE, MotionEvent.BUTTON_PRIMARY))
    }

    @Test
    fun theCoreTableIsReachableFromKotlin() {
        // 綁定沒接上的話，失敗模式在畫面上看起來只是「側鍵沒反應」。
        val controls = PenControls()
        assertEquals(
            FfiPenOutcome.USE_ERASER,
            controls.outcome(FfiPenControl.BARREL_PRIMARY, true, false, false))
        assertEquals(
            FfiPenOutcome.USE_LAST_BRUSH,
            controls.outcome(FfiPenControl.BARREL_PRIMARY, false, true, false))
    }

    @Test
    fun aSideButtonIsHeldNotToggled() {
        // 分類錯的話，使用者碰一下側鍵就永遠停在橡皮擦。
        val controls = PenControls()
        assertTrue(controls.isMomentary(FfiPenControl.BARREL_PRIMARY))
        assertTrue(controls.isMomentary(FfiPenControl.INVERT))
        assertFalse(controls.isMomentary(FfiPenControl.DOUBLE_TAP))
    }

    @Test
    fun settingsSurviveEncodingAndDecoding() {
        val controls = PenControls()
        controls.setAction(FfiPenControl.BARREL_SECONDARY, uniffi.padnote_core.FfiPenAction.UNDO)
        val restored = PenControls.decode(controls.encode())
        assertEquals(
            uniffi.padnote_core.FfiPenAction.UNDO,
            restored.action(FfiPenControl.BARREL_SECONDARY))
        // 沒動過的維持預設，不是被清成 none。
        assertEquals(
            uniffi.padnote_core.FfiPenAction.ERASER,
            restored.action(FfiPenControl.BARREL_PRIMARY))
    }

    @Test
    fun bothPlatformsGetTheSameAnswerForTheSameButton() {
        // 這一條是整份測試的重點：規則只有一份。Apple 端的
        // `PenHardwareTests.testTheCoreTableIsReachableFromSwift` 斷言的是
        // **同樣的輸入與輸出** —— 兩邊對不上的話，其中一邊會先紅。
        val controls = PenControls()
        assertEquals(
            FfiPenOutcome.USE_ERASER,
            controls.outcome(FfiPenControl.BARREL_PRIMARY, true, false, false))
        assertEquals(
            FfiPenOutcome.USE_LAST_BRUSH,
            controls.outcome(FfiPenControl.BARREL_PRIMARY, false, true, false))
    }
}
