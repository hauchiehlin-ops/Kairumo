package com.kairumo.padnote.ai

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.padnote_core.FfiTodoItem

/**
 * 摘要與待辦的入口（工作項 S-20）。
 *
 * 模型本身不在這裡驗 —— 這台裝置上根本沒有裝置端後端（見 [NoteIntelligence]
 * 的說明）。能驗、而且真的會出錯的是兩件事：
 *
 * 1. **餵給模型的文字**取得對不對，以及與 Apple 端是不是同一份規則；
 * 2. **沒有後端時的行為**是不是「明確地說沒有」，而不是一個看起來像暫時性
 *    失敗的錯誤。
 *
 * Apple 端的對照組是 `NoteIntelligenceTests.swift`，字串刻意逐字相同。
 */
@RunWith(AndroidJUnit4::class)
class NoteIntelligenceTest {

    @Test
    fun anEmptyNoteProducesEmptyText() {
        assertEquals("", notePlainText(title = "  "))
    }

    @Test
    fun blankPiecesAreDroppedInsteadOfLeavingHoles() {
        // 模型會把一整排空行當成章節分隔，然後為每一段「章節」各寫一句摘要。
        val text = notePlainText(
            title = "會議記錄",
            textBoxes = listOf("", "   ", "下週三交初稿", "\n")
        )
        assertEquals("會議記錄\n\n下週三交初稿", text)
    }

    @Test
    fun handwritingComesBeforeTypedText() {
        // 手寫多半是主體，文字方塊常常只是標註。順序反過來的話，
        // 摘要會以標註為重點。
        val text = notePlainText(
            title = "T",
            recognized = listOf("手寫的主體"),
            textBoxes = listOf("旁邊的標註")
        )
        assertTrue(text.indexOf("手寫的主體") < text.indexOf("旁邊的標註"))
    }

    @Test
    fun tableCellsAreSeparatedByNewlinesNotSpaces() {
        // 接成一長串的話，「姓名 王小明 電話」會被讀成一句話。
        val text = notePlainText(title = "T", tableCells = listOf("姓名", "王小明", "電話"))
        assertTrue("表格的格子被接成一句話了：$text", text.contains("姓名\n王小明\n電話"))
    }

    @Test
    fun everySourceSearchLooksAtIsIncluded() {
        // 與首頁搜尋比對的來源不一致的話，會出現一個很難解釋的狀況：
        // 使用者搜得到某句話，但摘要說筆記裡沒有提到它。
        val text = notePlainText(
            title = "標題",
            recognized = listOf("手寫"),
            textBoxes = listOf("打字"),
            tableCells = listOf("表格"),
            shapeLabels = listOf("形狀")
        )
        for (piece in listOf("標題", "手寫", "打字", "表格", "形狀")) {
            assertTrue("$piece 沒有被放進去", text.contains(piece))
        }
    }

    @Test
    fun withoutABackendTheResultSaysSoInsteadOfLookingTransient() {
        // **這一條是重點。** 回一個看起來像暫時性失敗的錯誤，使用者會一直按；
        // `needsModel` 才是讓畫面知道「這不是重試能解決的」的旗標。
        val result = NoteIntelligence.summarize("一些文字", "zh-Hant")
        assertFalse(result.ok)
        assertTrue("沒有標成需要模型，使用者會一直重試", result.needsModel)
    }

    @Test
    fun theAvailabilityMatchesWhatTheBackendActuallyDoes() {
        // 兩者不一致的話，畫面會給一顆按下去必定失敗的按鈕。
        val claimsAvailable = NoteIntelligence.availability() ==
            NoteIntelligence.Availability.AVAILABLE
        val actuallyWorks = NoteIntelligence.summarize("x", "en").ok
        assertEquals(claimsAvailable, actuallyWorks)
    }

    @Test
    fun theInsertedTextUsesMarkdownCheckboxes() {
        // 使用者接下來多半會勾掉其中幾條。
        // **與 Apple 端逐字相同** —— 同一則筆記在兩台裝置上插出來的東西
        // 要長得一樣，否則同步之後會看到兩種格式。
        val text = insertableText(
            summary = "談了三件事。",
            todos = listOf(
                FfiTodoItem("交初稿", false),
                FfiTodoItem("寄發票", true)
            ),
            l = { key -> key }
        )
        assertEquals(
            "## ai_key_points\n\n談了三件事。\n\n## ai_todos\n\n- [ ] 交初稿\n- [x] 寄發票",
            text
        )
    }

    @Test
    fun aSummaryWithNoTodosStillInsertsCleanly() {
        // 沒有待辦是正常的答案。插出來不該留一個空的「待辦事項」標題。
        val text = insertableText("只有摘要。", emptyList(), l = { it })
        assertEquals("## ai_key_points\n\n只有摘要。", text)
    }
}
