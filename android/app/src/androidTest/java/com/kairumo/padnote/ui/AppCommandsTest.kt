package com.kairumo.padnote.ui

import android.view.KeyEvent
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.kairumo.padnote.ink.InkTool
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 鍵盤快捷鍵的鍵位對照（工作項 S-65）。
 *
 * # 這裡驗的是哪一半
 *
 * 一個快捷鍵能用有兩段：**按鍵被翻成命令**（這裡），與**命令送到畫面之後
 * 真的有反應**（那要接鍵盤的實機或 ChromeOS）。把第一段釘住是有意義的 ——
 * 少檢查一次 Ctrl、或數字鍵算錯一格，都會讓快捷鍵**安靜地**做錯事：
 * 在文字框裡打「2024」變成切換四次工具，而且不會有任何錯誤。
 */
@RunWith(AndroidJUnit4::class)
class AppCommandsTest {

    @Test
    fun plainKeysAreNotShortcuts() {
        // 沒按 Ctrl 就什麼都不是 —— 否則在搜尋框裡打字會觸發快捷鍵。
        for (key in listOf(KeyEvent.KEYCODE_N, KeyEvent.KEYCODE_F, KeyEvent.KEYCODE_1)) {
            assertNull(
                "沒按 Ctrl 的 $key 不該是快捷鍵",
                AppCommands.command(key, ctrlPressed = false, shiftPressed = false))
        }
    }

    @Test
    fun newNotebookNeedsShift() {
        // Ctrl+Shift+N 才是新增；只有 Ctrl+N 不算 —— 與 Apple 端的 ⇧⌘N 一致。
        assertEquals(
            AppCommand.NewNotebook,
            AppCommands.command(KeyEvent.KEYCODE_N, ctrlPressed = true, shiftPressed = true))
        assertNull(
            AppCommands.command(KeyEvent.KEYCODE_N, ctrlPressed = true, shiftPressed = false))
    }

    @Test
    fun ctrlFFocusesSearch() {
        assertEquals(
            AppCommand.FocusSearch,
            AppCommands.command(KeyEvent.KEYCODE_F, ctrlPressed = true, shiftPressed = false))
    }

    @Test
    fun ctrlETogglesEditorMode() {
        assertEquals(
            AppCommand.ToggleEditorMode,
            AppCommands.command(KeyEvent.KEYCODE_E, ctrlPressed = true, shiftPressed = false))
    }

    @Test
    fun eachDigitCarriesItsOwnToolIndex() {
        // Ctrl+1 是第 0 個工具。差一格的話，使用者按「鋼筆」會拿到原子筆。
        for (index in 0 until AppCommands.MAX_TOOL_SHORTCUTS) {
            assertEquals(
                AppCommand.SelectTool(index),
                AppCommands.command(
                    KeyEvent.KEYCODE_1 + index, ctrlPressed = true, shiftPressed = false))
        }
    }

    @Test
    fun thereIsAShortcutForEveryTool() {
        // 工具列以後加到第十支筆時，這條會提醒數字鍵不夠用了 ——
        // 不提醒的話那支筆就是沒有快捷鍵，而且不會有任何錯誤。
        // Apple 端有一條一模一樣的（見 AppCommandTests.swift）。
        assertEquals(
            "工具比數字鍵多，第十支之後按不到",
            true,
            InkTool.entries.size <= AppCommands.MAX_TOOL_SHORTCUTS)
    }
}
