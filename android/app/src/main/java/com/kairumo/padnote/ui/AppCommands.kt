package com.kairumo.padnote.ui

import android.view.KeyEvent
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * 實體鍵盤快捷鍵（工作項 S-65）。
 *
 * # 為什麼 Android 也要有
 *
 * 在此之前**只有 Apple 端**有快捷鍵。接著鍵盤的 Android 平板（以及
 * ChromeOS、DeX）因此少了一整層操作：新增一本筆記要伸手點畫面，
 * 搜尋要先找到搜尋框。這是既有的跨平台缺口，不是新功能。
 *
 * # 鍵位對照
 *
 * Apple 用 ⌘，Android 用 **Ctrl** —— 這是平台慣例，不是隨便挑的。
 *
 * | 動作 | Apple | Android |
 * |---|---|---|
 * | 新增筆記 | ⇧⌘N | Ctrl+Shift+N |
 * | 搜尋 | ⌘F | Ctrl+F |
 * | 選工具 | ⌘1–⌘9 | Ctrl+1–Ctrl+6 |
 *
 * 新增筆記跟著 Apple 用**加 Shift** 的組合：Apple 端 ⌘N 被系統的
 * 「新增視窗」佔走（搶同一組鍵會讓 UIKit 直接丟例外），兩邊用同一組
 * 手勢比各用各的好記。
 *
 * 工具只到 6 是因為 **Android 只有六支**（見 `InkTool`）。Apple 有九支。
 * 數字鍵對應的是各自平台的工具列順序，不是硬湊成一樣長。
 *
 * # 為什麼走事件流而不是直接改狀態
 *
 * 按鍵事件到得了 `Activity`，但狀態在 Compose 的 `remember` 裡。用一條
 * 事件流把兩邊接起來：Activity 不必知道有哪些畫面，畫面也不必知道
 * 命令是從鍵盤還是別的地方來的。這與 Apple 端用通知的理由相同。
 */
sealed interface AppCommand {
    /** 新增筆記本。 */
    data object NewNotebook : AppCommand

    /** 把游標送進搜尋框。 */
    data object FocusSearch : AppCommand

    /** 切換手寫／打字模式。 */
    data object ToggleEditorMode : AppCommand

    /** 選第 [index] 個工具（從 0 起算）。 */
    data class SelectTool(val index: Int) : AppCommand
}

object AppCommands {

    // extraBufferCapacity = 1：沒有 replay。按鍵是「當下發生的事」，
    // 補送一個舊的給剛出現的畫面只會讓它自己跳掉。
    private val _events = MutableSharedFlow<AppCommand>(extraBufferCapacity = 1)

    val events: SharedFlow<AppCommand> = _events.asSharedFlow()

    fun send(command: AppCommand) {
        _events.tryEmit(command)
    }

    /** 工具快捷鍵最多到 9 —— 數字鍵就這麼多個。 */
    const val MAX_TOOL_SHORTCUTS: Int = 9

    /**
     * 把按鍵翻成命令；不是快捷鍵就回 null。
     *
     * 抽成純函式是為了能單獨測：`Activity` 的按鍵處理沒辦法在單元測試裡跑，
     * 而「Ctrl 沒按住也觸發」這種錯誤只會在實機上被發現。
     */
    fun command(keyCode: Int, ctrlPressed: Boolean, shiftPressed: Boolean): AppCommand? {
        if (!ctrlPressed) return null
        return when (keyCode) {
            // 新增筆記要**加 Shift**。只有 Ctrl+N 的話，
            // 在文字框裡打字的人按到它會莫名其妙多一本筆記。
            KeyEvent.KEYCODE_N -> if (shiftPressed) AppCommand.NewNotebook else null
            KeyEvent.KEYCODE_F -> if (shiftPressed) null else AppCommand.FocusSearch
            KeyEvent.KEYCODE_E -> if (shiftPressed) null else AppCommand.ToggleEditorMode
            else -> {
                if (shiftPressed) return null
                val digit = keyCode - KeyEvent.KEYCODE_1
                if (digit in 0 until MAX_TOOL_SHORTCUTS) AppCommand.SelectTool(digit) else null
            }
        }
    }
}
