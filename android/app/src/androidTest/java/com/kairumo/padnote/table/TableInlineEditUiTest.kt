package com.kairumo.padnote.table

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performImeAction
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.kairumo.padnote.canvas.EditorMode
import com.kairumo.padnote.canvas.LocalEditorMode
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 表格儲存格就地輸入（與 Apple 的 `testTypeModeTapOnABlankTableCellSelectsTheTableAndEditsTheCell` 對應）。
 *
 * 使用者回報：表格內無法編輯儲存格。Android 原本只能點兩下開編修面板改字；
 * 現在點一下空白格就選取表格並出現輸入框，打的字直接寫回表格，「下一個」跳到右邊一格。
 */
@RunWith(AndroidJUnit4::class)
class TableInlineEditUiTest {

    @get:Rule val rule = createComposeRule()

    @Test
    fun tappingABlankCellSelectsTheTableAndTypesIntoIt() {
        val table = NoteTable(id = "t", x = 40f, y = 40f, width = 300f, rows = 3, cols = 3)
        var selected by mutableStateOf<String?>(null)
        var density = 1f
        rule.setContent {
            density = LocalDensity.current.density
            CompositionLocalProvider(LocalEditorMode provides EditorMode.TYPE) {
                Box(Modifier.size(600.dp)) {
                    TableLayer(
                        interactive = true, tables = listOf(table), density = density,
                        selectedId = selected, onSelect = { selected = it }, onEdit = {},
                        onChanged = {}, zIndexOf = { 0f }, modifier = Modifier.fillMaxSize()
                    )
                }
            }
        }
        // 第 2 列、第 2 欄那一格的中心（頁面點 → 像素）。
        val cell = table.layout().cells.first { it.row.toInt() == 1 && it.col.toInt() == 1 }
        val tap = Offset(
            ((table.x + cell.x + cell.width / 2) * density).toFloat(),
            ((table.y + cell.y + cell.height / 2) * density).toFloat())
        rule.onRoot().performTouchInput { click(tap) }
        // 表格也認「點兩下開面板」，單擊要等雙擊的判定時間過了才送出。
        rule.mainClock.advanceTimeBy(600)
        rule.waitForIdle()
        assertEquals("點空白格要選取表格", "t", selected)

        rule.onNodeWithTag("table.cell.editor").performTextInput("Hi")
        rule.waitForIdle()
        assertEquals("儲存格要打得進字", "Hi", table.cell(1, 1))

        // 「下一個」跳到右邊一格繼續打。
        rule.onNodeWithTag("table.cell.editor").performImeAction()
        rule.onNodeWithTag("table.cell.editor").performTextInput("Yo")
        rule.waitForIdle()
        assertEquals("Yo", table.cell(1, 2))
    }
}
