package com.kairumo.padnote.editor

import com.kairumo.padnote.canvas.EditorMode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 編輯器狀態機單元測試（與 Apple 端 EditorStateMachineTests 案例完全對稱）
 */
class EditorStateManagerTest {

    @Test
    fun initialModeDefaultsToDrawAndDrawingPhase() {
        val sm = EditorStateManager()
        assertEquals(EditorMode.DRAW, sm.currentMode)
        assertEquals(EditorInteractionPhase.Drawing, sm.phase)
        assertTrue(sm.isInkDrawingAllowed)
        assertFalse(sm.isCanvasTapCreatesText)
        assertFalse(sm.isObjectDirectSelectionAllowed)
    }

    @Test
    fun modeSwitchingUpdatesPhaseAndInvariants() {
        val sm = EditorStateManager()

        // 切換至打字模式
        val changed = sm.setMode(EditorMode.TYPE)
        assertTrue(changed)
        assertEquals(EditorMode.TYPE, sm.currentMode)
        assertFalse(sm.isInkDrawingAllowed)
        assertTrue(sm.isCanvasTapCreatesText)
        assertTrue(sm.isObjectDirectSelectionAllowed)

        // 重複切換同一模式應回傳 false
        assertFalse(sm.setMode(EditorMode.TYPE))

        // 切回手繪模式
        assertTrue(sm.setMode(EditorMode.DRAW))
        assertEquals(EditorMode.DRAW, sm.currentMode)
        assertTrue(sm.isInkDrawingAllowed)
        assertFalse(sm.isCanvasTapCreatesText)
        assertFalse(sm.isObjectDirectSelectionAllowed)
    }

    @Test
    fun switchingFromTypeToDrawClearsActiveTextAndCell() {
        val sm = EditorStateManager()
        sm.beginTextEditing("text-123")
        assertEquals(EditorMode.TYPE, sm.currentMode)
        assertEquals("text-123", sm.activeTextId)

        // 切回 DRAW 時應自動清除選取
        sm.setMode(EditorMode.DRAW)
        assertEquals(EditorMode.DRAW, sm.currentMode)
        assertNull(sm.activeTextId)
        assertNull(sm.activeTableCell)
        assertEquals(EditorInteractionPhase.Drawing, sm.phase)
    }

    @Test
    fun modalStudioFreezesInkAndTextCreation() {
        val sm = EditorStateManager()
        assertTrue(sm.isInkDrawingAllowed)

        // 開啟工作坊 Modal
        sm.updateModalActive(true)
        assertTrue(sm.isModalActive)
        assertEquals(EditorInteractionPhase.ModalStudio, sm.phase)
        assertFalse(sm.isInkDrawingAllowed)
        assertFalse(sm.isCanvasTapCreatesText)
        assertFalse(sm.isObjectDirectSelectionAllowed)

        // 關閉工作坊 Modal
        sm.updateModalActive(false)
        assertFalse(sm.isModalActive)
        assertEquals(EditorInteractionPhase.Drawing, sm.phase)
        assertTrue(sm.isInkDrawingAllowed)
    }

    @Test
    fun stylusTouchInTypeModeDoesNotSwitchMode() {
        val sm = EditorStateManager(initialMode = EditorMode.TYPE)
        assertEquals(EditorMode.TYPE, sm.currentMode)

        // 核心守衛：打字模式下碰觸觸控筆，不可切回 DRAW
        val allowed = sm.handleStylusTouch()
        assertFalse(allowed)
        assertEquals(EditorMode.TYPE, sm.currentMode)
        assertFalse(sm.isInkDrawingAllowed)
    }

    @Test
    fun toggleModeAlternatesCleanly() {
        val sm = EditorStateManager(initialMode = EditorMode.DRAW)
        sm.toggleMode()
        assertEquals(EditorMode.TYPE, sm.currentMode)
        sm.toggleMode()
        assertEquals(EditorMode.DRAW, sm.currentMode)
    }

    @Test
    fun tableCellSelectionUpdatesPhase() {
        val sm = EditorStateManager(initialMode = EditorMode.TYPE)
        sm.selectTableCell(2, 3)
        assertEquals(TableCellCoordinate(2, 3), sm.activeTableCell)
        assertNull(sm.activeTextId)
        assertEquals(EditorInteractionPhase.Selecting, sm.phase)

        sm.clearAllSelection()
        assertNull(sm.activeTableCell)
        assertEquals(EditorInteractionPhase.Typing(null), sm.phase)
    }
}
