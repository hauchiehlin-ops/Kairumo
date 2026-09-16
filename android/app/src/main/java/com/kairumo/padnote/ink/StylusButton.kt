package com.kairumo.padnote.ink

import android.view.MotionEvent

/**
 * 觸控筆的「快速切橡皮擦」手勢（工作項 S-67，Android 端）。
 *
 * # 跟 Apple 那邊不是同一個硬體事件
 *
 * Apple Pencil 有**雙擊筆桿**，Android 沒有 —— 那是 Apple Pencil 的硬體
 * 特性，系統層根本不會產生這個事件。Android 上對應的原生手勢是**筆桿側鍵**
 * （`BUTTON_STYLUS_PRIMARY`，S Pen 與多數主動式觸控筆都有），而且多數
 * Android 手寫 App 的側鍵就是橡皮擦，使用者的預期已經在那裡了。
 *
 * 所以兩邊**觸發方式不同，結果一致**：切成橡皮擦，回來時回到**最後用過的
 * 筆刷**。Apple 端的規則在 `PencilDoubleTap.swift`。
 *
 * # 為什麼是「按著」而不是「切換」
 *
 * 側鍵是一顆按著的實體鍵，不是開關。按著擦、放開回到筆，是使用者按下去
 * 時預期的事；做成切換的話，按一下放開之後筆還是橡皮擦，而畫面上唯一的
 * 提示在工具列上 —— 使用者會以為自己的筆壞了。
 *
 * # 反向筆頭
 *
 * 有些筆（S Pen、Surface Pen）把筆倒過來會直接回報 `TOOL_TYPE_ERASER`。
 * 那也走同一條路 —— 對使用者來說是同一件事。
 *
 * 側鍵事件要**實體觸控筆**才發得出來（模擬器沒有，`adb input` 也送不出
 * `buttonState`），所以下面的規則用單元測試驗，實機行為列 S-40。
 */
object StylusButton {

    /** 這個事件是不是「現在要擦」。按著側鍵，或是把筆倒過來用。 */
    fun isErasing(toolType: Int, buttonState: Int): Boolean =
        toolType == MotionEvent.TOOL_TYPE_ERASER ||
            (buttonState and MotionEvent.BUTTON_STYLUS_PRIMARY) != 0

    fun isErasing(event: MotionEvent): Boolean =
        isErasing(event.getToolType(0), event.buttonState)

    /**
     * 手勢狀態 + 目前狀態 → 工具列現在該選什麼。
     *
     * 回傳 `null` 表示「不用動」。
     *
     * @param erasing 側鍵按著（或筆倒過來）。
     * @param current 目前選中的工具。
     * @param lastBrush 最後用過的**筆刷**（不會是橡皮擦或套索）。
     */
    fun outcome(erasing: Boolean, current: InkTool, lastBrush: InkTool): InkTool? {
        // 防呆：`lastBrush` 不該是橡皮擦或套索，但真的傳進來的話，
        // 放開側鍵會變成原地不動 —— 退回預設的鋼筆。
        val brush = if (lastBrush.kind != null) lastBrush else InkTool.FOUNTAIN_PEN

        return when {
            erasing -> if (current == InkTool.ERASER) null else InkTool.ERASER
            // 沒按著側鍵時只還原**我們自己切過去的那一次**：使用者是自己
            // 在工具列上選了橡皮擦的話，這裡不能把它換掉。兩者的差別由
            // 呼叫端記著（見 `MainActivity` 的 `stylusHeldEraser`）。
            current == InkTool.ERASER -> brush
            else -> null
        }
    }
}
