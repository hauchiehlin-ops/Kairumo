package com.kairumo.padnote.editor

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.kairumo.padnote.canvas.EditorMode

/**
 * 編輯器互動階段（與 Apple 端 EditorInteractionPhase 完全對稱）
 */
sealed interface EditorInteractionPhase {
    data object Drawing : EditorInteractionPhase
    data class Typing(val activeTextId: String?) : EditorInteractionPhase
    data object Selecting : EditorInteractionPhase
    data object ModalStudio : EditorInteractionPhase
}

/**
 * 儲存格座標（行、列）
 */
data class TableCellCoordinate(val row: Int, val col: Int)

/**
 * 統一編輯器全域狀態機（Android 端對等實作）：
 * 解決手勢衝突、模式互搶、打字與手繪邊界模糊的根本架構元件。
 * 遵循標準單一職責模式設計，提供互斥守衛與零回退保障。
 */
class EditorStateManager(initialMode: EditorMode = EditorMode.DRAW) {

    /** 當前主模式（手寫 DRAW vs 打字 TYPE） */
    var currentMode by mutableStateOf(initialMode)
        private set

    /** 當前互動階段 */
    var phase: EditorInteractionPhase by mutableStateOf(
        if (initialMode == EditorMode.DRAW) EditorInteractionPhase.Drawing
        else EditorInteractionPhase.Typing(null)
    )
        private set

    /** 當前行內編輯中的文字方塊 ID（打字模式下） */
    var activeTextId by mutableStateOf<String?>(null)
        private set

    /** 當前選取或行內編輯的表格儲存格座標 */
    var activeTableCell by mutableStateOf<TableCellCoordinate?>(null)
        private set

    /** 次級視窗或工作坊是否正在展示 */
    var isModalActive by mutableStateOf(false)
        private set

    // MARK: - Computed Invariants (狀態守衛保證)

    /** 畫布是否允許繪製墨水：僅在手寫模式（DRAW）且無次級工作坊時啟用，文字模式下 100% 關閉 */
    val isInkDrawingAllowed: Boolean
        get() = !isModalActive && currentMode == EditorMode.DRAW

    /** 畫布空白處點擊是否應建立或聚焦文字方塊：僅在打字模式（TYPE）下啟用 */
    val isCanvasTapCreatesText: Boolean
        get() = !isModalActive && currentMode == EditorMode.TYPE

    /** 畫布上的物件（表格、便利貼、圖表）是否允許直接選取或拖曳：在打字模式（TYPE）下啟用 */
    val isObjectDirectSelectionAllowed: Boolean
        get() = !isModalActive && currentMode == EditorMode.TYPE

    // MARK: - State Transitions (模式切換與守衛)

    /**
     * 請求切換主編輯模式
     * @param targetMode 目標模式（DRAW 或 TYPE）
     * @return 切換是否成功
     */
    fun setMode(targetMode: EditorMode): Boolean {
        if (currentMode == targetMode) return false

        // 離開打字模式時，自動收合未儲存的輸入焦點
        if (currentMode == EditorMode.TYPE && targetMode == EditorMode.DRAW) {
            activeTextId = null
            activeTableCell = null
        }

        currentMode = targetMode
        updatePhase()
        return true
    }

    /** 切換模式（快捷鍵或切換鈕） */
    fun toggleMode() {
        setMode(if (currentMode == EditorMode.DRAW) EditorMode.TYPE else EditorMode.DRAW)
    }

    /**
     * 觸控筆（Stylus / S-Pen）觸碰畫布時的回呼
     * @return true 表示此觸碰應作為筆跡處理；false 表示應作為點擊/游標指針處理（不可切換模式）
     */
    fun handleStylusTouch(): Boolean {
        // 核心守衛：若當前為打字模式，絕對不允許觸控筆觸碰自動切換回 DRAW
        return currentMode == EditorMode.DRAW
    }

    /** 點選文字方塊進行行內編輯 */
    fun beginTextEditing(id: String) {
        if (currentMode != EditorMode.TYPE) {
            currentMode = EditorMode.TYPE
        }
        activeTextId = id
        activeTableCell = null
        updatePhase()
    }

    /** 結束文字方塊編輯 */
    fun endTextEditing() {
        activeTextId = null
        updatePhase()
    }

    /** 點選表格儲存格進行行內編輯 */
    fun selectTableCell(row: Int, col: Int) {
        activeTableCell = TableCellCoordinate(row = row, col = col)
        activeTextId = null
        updatePhase()
    }

    /** 清空所有物件選取與行內編輯焦點 */
    fun clearAllSelection() {
        activeTextId = null
        activeTableCell = null
        updatePhase()
    }

    /** 設定次級視窗 / 工作坊開關狀態 */
    fun updateModalActive(active: Boolean) {
        if (isModalActive != active) {
            isModalActive = active
            updatePhase()
        }
    }

    // MARK: - Private Helpers

    private fun updatePhase() {
        phase = when {
            isModalActive -> EditorInteractionPhase.ModalStudio
            activeTableCell != null -> EditorInteractionPhase.Selecting
            currentMode == EditorMode.TYPE -> EditorInteractionPhase.Typing(activeTextId)
            else -> EditorInteractionPhase.Drawing
        }
    }
}
