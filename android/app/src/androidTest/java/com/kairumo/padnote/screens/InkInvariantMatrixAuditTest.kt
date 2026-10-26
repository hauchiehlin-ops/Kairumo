package com.kairumo.padnote.screens

import android.content.Context
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.MainActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 筆跡不變式矩陣（Android 端，與 Apple 的 InkInvariantMatrixAudit 對應）。
 *
 * # 守護的不變式
 *
 * 1. 模式切換（DRAW <-> TYPE）：切換模式不改變任何筆畫。
 * 2. 顯示模式切換（SINGLE <-> CONTINUOUS）：切換版面配置筆畫不准消失或歸零。
 * 3. 側欄縮圖切換頁面：每一頁的筆跡維持各自的數量，防止空頁面覆蓋與序號錯位。
 */
@RunWith(AndroidJUnit4::class)
class InkInvariantMatrixAuditTest {

    @get:Rule
    val compose = createEmptyComposeRule()

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    private fun skipOnboarding() {
        context.getSharedPreferences("kairumo_onboarding", Context.MODE_PRIVATE)
            .edit().putBoolean("seen_v1", true).commit()
    }

    private fun openFirstNotebook() {
        val listMatcher = hasTestTag("home.notebooks.list")
        val matcher = SemanticsMatcher("testTag 以 home.notebooks.card. 開頭") { node ->
            node.config.getOrNull(SemanticsProperties.TestTag)
                ?.startsWith("home.notebooks.card.") == true
        }
        compose.waitUntil(timeoutMillis = 60_000) {
            if (compose.onAllNodes(matcher).fetchSemanticsNodes().isEmpty()) {
                runCatching {
                    compose.onNodeWithTag("home.scroll")
                        .performScrollToNode(listMatcher)
                    compose.waitForIdle()
                }
                runCatching {
                    compose.onNodeWithTag("home.scroll")
                        .performScrollToNode(matcher)
                    compose.waitForIdle()
                }
            }
            compose.onAllNodes(matcher).fetchSemanticsNodes().isNotEmpty()
        }

        val cards = compose.onAllNodes(matcher)
        val nodes = cards.fetchSemanticsNodes()
        assertTrue("首頁找不到任何筆記卡片", nodes.isNotEmpty())
        cards[0].performClick()

        compose.waitUntil(timeoutMillis = 30_000) {
            listOf("editor.more", "editor.share", "editor.sidebar_toggle").any {
                compose.onAllNodesWithTag(it).fetchSemanticsNodes().isNotEmpty()
            }
        }
        compose.waitForIdle()
    }

    /**
     * 從畫布無障礙值讀出目前筆畫數 `strokes:N`。
     */
    private fun parseStrokeCount(): Int? {
        val canvasNodes = compose.onAllNodesWithTag("editor.canvas").fetchSemanticsNodes()
        for (node in canvasNodes) {
            val desc = node.config.getOrNull(SemanticsProperties.ContentDescription)?.firstOrNull() ?: continue
            if (desc.startsWith("strokes:")) {
                return desc.removePrefix("strokes:").toIntOrNull()
            }
        }
        return null
    }

    @Test
    fun modeSwitchingPreservesInk() {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            openFirstNotebook()

            val initialStrokes = parseStrokeCount()
            assertNotNull("應能讀取到手繪畫布筆畫數", initialStrokes)

            // 切換到打字模式
            if (compose.onAllNodesWithTag("portal.type").fetchSemanticsNodes().isNotEmpty()) {
                compose.onNodeWithTag("portal.type").performClick()
                compose.waitForIdle()

                val typedStrokes = parseStrokeCount()
                assertEquals("切換到打字模式後筆畫不准消失或改變", initialStrokes, typedStrokes)
            }

            // 切回手繪模式
            if (compose.onAllNodesWithTag("portal.draw").fetchSemanticsNodes().isNotEmpty()) {
                compose.onNodeWithTag("portal.draw").performClick()
                compose.waitForIdle()

                val backStrokes = parseStrokeCount()
                assertEquals("切回手繪模式後筆畫必須完好留存", initialStrokes, backStrokes)
            }
        }
    }

    @Test
    fun displayModeTogglePreservesInk() {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            openFirstNotebook()

            val initialStrokes = parseStrokeCount()
            assertNotNull("切換前應能讀取到筆畫數", initialStrokes)

            // 切換到連續頁面模式
            if (compose.onAllNodesWithTag("editor.page.display_mode").fetchSemanticsNodes().isNotEmpty()) {
                compose.onNodeWithTag("editor.page.display_mode").performClick()
                compose.waitForIdle()

                // 切回單頁模式
                compose.onNodeWithTag("editor.page.display_mode").performClick()
                compose.waitForIdle()

                val restoredStrokes = parseStrokeCount()
                assertEquals("版面切換往返後筆畫不應遺失", initialStrokes, restoredStrokes)
            }
        }
    }

    @Test
    fun thumbnailPageSwitchingPreservesEachPagesInk() {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            openFirstNotebook()

            // 展開側欄
            if (compose.onAllNodesWithTag("editor.sidebar_toggle").fetchSemanticsNodes().isNotEmpty()) {
                compose.onNodeWithTag("editor.sidebar_toggle").performClick()
                compose.waitForIdle()
            }

            val p0Strokes = parseStrokeCount()

            // 點第 1 頁縮圖（如果存在）
            if (compose.onAllNodesWithTag("sidebar.page.1").fetchSemanticsNodes().isNotEmpty()) {
                compose.onNodeWithTag("sidebar.page.1").performClick()
                compose.waitForIdle()

                val p1Strokes = parseStrokeCount()
                assertNotNull("切換到第 1 頁後應有筆跡狀態", p1Strokes)

                // 切回第 0 頁
                if (compose.onAllNodesWithTag("sidebar.page.0").fetchSemanticsNodes().isNotEmpty()) {
                    compose.onNodeWithTag("sidebar.page.0").performClick()
                    compose.waitForIdle()

                    val p0Back = parseStrokeCount()
                    assertEquals("切回第 0 頁後筆畫數應維持原樣，不可被空頁覆蓋", p0Strokes, p0Back)
                }
            }
        }
    }
}
