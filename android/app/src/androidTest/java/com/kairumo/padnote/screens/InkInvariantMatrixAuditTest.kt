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
import com.kairumo.padnote.ui.FeatureHintStore
import com.kairumo.padnote.ui.Onboarding
import org.junit.After
import org.junit.Before
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
 *
 * 測試入口找不到時直接失敗，不准 silently pass。
 */
@RunWith(AndroidJUnit4::class)
class InkInvariantMatrixAuditTest {

    @get:Rule
    val compose = createEmptyComposeRule()

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Before
    fun setup() {
        FeatureHintStore.forceDismissAllForTesting = true
        skipOnboarding()
    }

    @After
    fun cleanup() {
        useDisplayMode(null)
    }

    private fun skipOnboarding() {
        FeatureHintStore.forceDismissAllForTesting = true
        Onboarding.markSeen(context)
        context.getSharedPreferences("kairumo_onboarding", Context.MODE_PRIVATE)
            .edit().putBoolean("seen_v1", true).commit()
    }

    private fun useDisplayMode(wire: String?) {
        val prefs = com.kairumo.padnote.profile.ProfileContext.prefs(context, "kairumo_editor").edit()
        if (wire == null) prefs.remove("pageDisplayMode") else prefs.putString("pageDisplayMode", wire)
        prefs.commit()
    }

    private fun tap(tag: String, why: String, timeout: Long = 15_000) {
        val ok = runCatching {
            compose.waitUntil(timeoutMillis = timeout) {
                compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()
            }
        }.isSuccess
        assertTrue("$why（找不到標記 $tag）", ok)
        compose.onNodeWithTag(tag).performClick()
        compose.waitForIdle()
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

    private fun modeSwitchingPreservesInkJourney() {
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            openFirstNotebook()

            val initialStrokes = parseStrokeCount()
            assertNotNull("應能讀取到手繪畫布筆畫數", initialStrokes)

            // 切換到打字模式
            tap("portal.type", "找不到切換到打字模式的入口")
            val typedStrokes = parseStrokeCount()
            assertEquals("切換到打字模式後筆畫不准消失或改變", initialStrokes, typedStrokes)

            // 切回手繪模式
            tap("portal.draw", "找不到切換到手繪模式的入口")
            val backStrokes = parseStrokeCount()
            assertEquals("切回手繪模式後筆畫必須完好留存", initialStrokes, backStrokes)
        }
    }

    @Test
    fun modeSwitchingPreservesInk_singlePage() {
        skipOnboarding()
        useDisplayMode("single")
        modeSwitchingPreservesInkJourney()
    }

    @Test
    fun modeSwitchingPreservesInk_continuousPages() {
        skipOnboarding()
        useDisplayMode("continuous")
        modeSwitchingPreservesInkJourney()
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
            tap("editor.page.display_mode", "找不到版面切換按鈕")

            // 切回單頁模式
            tap("editor.page.display_mode", "找不到版面切換按鈕")

            val restoredStrokes = parseStrokeCount()
            assertEquals("版面切換往返後筆畫不應遺失", initialStrokes, restoredStrokes)
        }
    }

    @Test
    fun thumbnailPageSwitchingPreservesEachPagesInk() {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            openFirstNotebook()

            // 展開側欄（若尚未展開，以 sidebar.page.0 判斷）
            val sidebarOpen = compose.onAllNodesWithTag("sidebar.page.0").fetchSemanticsNodes().isNotEmpty()
            if (!sidebarOpen) {
                tap("editor.sidebar_toggle", "找不到側欄切換按鈕")
                compose.waitUntil(timeoutMillis = 5_000) {
                    compose.onAllNodesWithTag("sidebar.page.0").fetchSemanticsNodes().isNotEmpty()
                }
            }

            // 若目前只有第 0 頁，點擊新增頁面以確保有第 1 頁
            val hasPage1 = compose.onAllNodesWithTag("sidebar.page.1").fetchSemanticsNodes().isNotEmpty()
            if (!hasPage1) {
                if (compose.onAllNodesWithTag("editor.page.add").fetchSemanticsNodes().isNotEmpty()) {
                    tap("editor.page.add", "找不到新增頁面按鈕")
                    compose.waitUntil(timeoutMillis = 10_000) {
                        compose.onAllNodesWithTag("sidebar.page.1").fetchSemanticsNodes().isNotEmpty()
                    }
                }
            }

            val p0Strokes = parseStrokeCount()

            // 點第 1 頁縮圖
            tap("sidebar.page.1", "找不到第 1 頁縮圖")
            val p1Strokes = parseStrokeCount()
            assertNotNull("切換到第 1 頁後應有筆跡狀態", p1Strokes)

            // 切回第 0 頁
            tap("sidebar.page.0", "找不到第 0 頁縮圖")
            val p0Back = parseStrokeCount()
            assertEquals("切回第 0 頁後筆畫數應維持原樣，不可被空頁覆蓋", p0Strokes, p0Back)
        }
    }
}
