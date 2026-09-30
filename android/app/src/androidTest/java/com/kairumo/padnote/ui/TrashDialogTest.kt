package com.kairumo.padnote.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.library.NotebookLibrary
import com.kairumo.padnote.library.NotebookTrash
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * 回收桶畫面真的點得動嗎（`TrashDialog`）。與 Apple 端的
 * `testTrashRoundTripFromTheHomeScreen` 是同一條路徑的另一半。
 *
 * # 為什麼需要它
 *
 * Apple 端的回收桶按鈕曾經按下去沒有任何反應 —— 編譯、單元測試、畫面稽核全是綠的，
 * 是 UI 測試實際點過才發現。Android 這邊原本也只驗證了搬檔案那一層
 * （`NotebookTrashTest`），沒有人操作過畫面。
 *
 * # 安全
 *
 * 這個測試操作的是 App **真正的**回收桶，所以前置條件是「回收桶裡只有我放進去的那一本」。
 * 不成立就略過 —— 寧可少測一次，也不要點到裝置上使用者自己放在回收桶裡的東西。
 */
@RunWith(AndroidJUnit4::class)
class TrashDialogTest {

    @get:Rule
    val compose = createComposeRule()

    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val id = "trash-ui-test-${UUID.randomUUID()}"

    private fun live() = File(NotebookLibrary.directory(context), "$id.${NotebookLibrary.EXTENSION}")

    @Before
    fun putOneNotebookInTheTrash() {
        assumeTrue(
            "回收桶裡已經有別的東西，不能冒險點到使用者自己的項目",
            NotebookTrash.trashedIds(context).isEmpty()
        )
        live().mkdirs()
        File(live(), "marker.txt").writeText("payload:$id")
        assertTrue(NotebookTrash.moveToTrash(context, id))
        assertEquals(listOf(id), NotebookTrash.trashedIds(context))
    }

    @After
    fun cleanUp() {
        NotebookTrash.purgeLocally(context, id)
    }

    private fun show() {
        compose.setContent {
            CompositionLocalProvider(LocalAppLanguage provides "en") {
                TrashDialog(onDismiss = {})
            }
        }
        compose.waitForIdle()
    }

    /**
     * 等二次確認框出現。**對話框是獨立的視窗**，點了按鈕之後它要一段時間才組合出來 ——
     * 立刻去找「Cancel」會找不到（第一版就是這樣失敗的：訊息說找不到節點，
     * 而它其實已經開了，語意樹裡有兩個視窗根）。
     */
    private fun awaitConfirmation() {
        compose.waitUntil(5_000) {
            compose.onAllNodesWithText("Cancel").fetchSemanticsNodes().isNotEmpty()
        }
    }

    @Test
    fun restoringFromTheDialogBringsTheNotebookBack() {
        show()
        compose.onNodeWithTag("trash.row").assertExists()

        compose.onNodeWithTag("trash.restore").performClick()
        compose.waitForIdle()

        compose.waitUntil(5_000) { NotebookTrash.trashedIds(context).isEmpty() }
        assertEquals("payload:$id", File(live(), "marker.txt").readText())
        compose.onNodeWithTag("trash.empty").assertExists()
    }

    @Test
    fun deletingPermanentlyAsksForConfirmationAndThenRemovesIt() {
        show()
        compose.onNodeWithTag("trash.deleteForever").performClick()
        awaitConfirmation()

        // 二次確認出現之後、按下確定之前，什麼都還在。
        assertEquals(listOf(id), NotebookTrash.trashedIds(context))

        // 列上的按鈕與確認框的按鈕字一樣；確認框在最上層，取最後一個。
        compose.onAllNodesWithText("Delete Permanently").onLast().performClick()

        compose.waitUntil(5_000) { NotebookTrash.trashedIds(context).isEmpty() }
        assertFalse("永久刪除之後不該在任何地方", live().exists())
        compose.onNodeWithTag("trash.empty").assertExists()
    }

    @Test
    fun cancellingTheConfirmationKeepsTheNotebook() {
        show()
        compose.onNodeWithTag("trash.deleteForever").performClick()
        awaitConfirmation()
        compose.onAllNodesWithText("Cancel").onFirst().performClick()

        compose.waitForIdle()
        assertEquals("取消要什麼都不動", listOf(id), NotebookTrash.trashedIds(context))
    }
}
