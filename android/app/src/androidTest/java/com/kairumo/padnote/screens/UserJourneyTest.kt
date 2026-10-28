package com.kairumo.padnote.screens

import android.content.Context
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.MainActivity
import com.kairumo.padnote.ui.FeatureHintStore
import com.kairumo.padnote.ui.Onboarding
import com.kairumo.padnote.ui.ToolbarSettings
import org.junit.After
import org.junit.Before
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 使用者旅程測試（P0）：從使用者會點的地方一路點到結果，驗的是「好用」而不只是「按鈕在」。
 * 與 Apple 的 `UserJourneyUITests` 一一對應。
 *
 * # 與既有稽核測試的差別
 *
 * 既有的稽核把斷言包在「找得到那顆按鈕才檢查」裡 —— 按鈕不見了測試照樣綠燈。
 * 這裡**找不到就失敗**：使用者找不到的入口，就是壞掉的功能。
 *
 * # 守的旅程
 *
 * 1. 工具列選了橡皮擦，畫下去就是在擦（拆檔後 Android 主工具列繞過 `applyInkTool`，
 *    選了橡皮擦畫下去還是墨跡 —— 這條測試會在那種回歸發生時紅掉）。
 * 2. 自訂飛梭工具盤：在設定裡拿掉一格，叫出工具盤就看不到它；選工具盤上的橡皮擦一樣真的會擦。
 */
@RunWith(AndroidJUnit4::class)
class UserJourneyTest {

    @get:Rule
    val compose = createEmptyComposeRule()

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    private val tag: String get() = com.kairumo.padnote.currentLanguageTag()

    @Before
    fun setup() {
        FeatureHintStore.forceDismissAllForTesting = true
        skipOnboarding()
    }

    @After
    fun restore() {
        // 設定跟著帳號跑：測完一定要還原，不然下一個測試（或開發者自己的裝置）工具盤就少一格。
        ToolbarSettings.resetRadial(context, tag)
        deleteJourneyNotebook()
        useDisplayMode(null)
    }

    private companion object {
        const val JOURNEY_ID = "uitest-journey"
    }

    private fun skipOnboarding() {
        FeatureHintStore.forceDismissAllForTesting = true
        Onboarding.markSeen(context)
        context.getSharedPreferences("kairumo_onboarding", Context.MODE_PRIVATE)
            .edit().putBoolean("seen_v1", true).commit()
    }

    private fun exists(tag: String) = compose.onAllNodesWithTag(tag).fetchSemanticsNodes().isNotEmpty()

    private fun waitFor(tag: String, why: String, timeout: Long = 15_000) {
        runCatching { compose.waitUntil(timeoutMillis = timeout) { exists(tag) } }
            .onFailure {
                val tree = runCatching {
                    compose.onAllNodes(SemanticsMatcher("任何節點") { true }).fetchSemanticsNodes()
                        .mapNotNull { it.config.getOrNull(SemanticsProperties.TestTag) }
                        .take(40).joinToString()
                }.getOrDefault("?")
                fail("$why（找不到 $tag；畫面上的標記：$tree）")
            }
    }

    private fun tap(tag: String, why: String) {
        waitFor(tag, why)
        val node = compose.onAllNodesWithTag(tag).onFirst()
        runCatching { node.performScrollTo() }
        node.performClick()
        compose.waitForIdle()
    }

    /**
     * 專屬的空白測試筆記（固定 id）：不碰使用者的筆記、不靠「首頁第一張卡片剛好是手寫筆記」。
     * 直接用 `open_notebook_id` 打開（與手動驗證腳本同一個入口）。
     */
    private fun launchJourneyNotebook(): ActivityScenario<MainActivity> {
        val saved = com.kairumo.padnote.profile.ProfileContext.prefs(context, "kairumo").getInt("deviceId", 0)
        val device = if (saved != 0) saved.toUInt() else 0xE7u
        deleteJourneyNotebook()
        com.kairumo.padnote.library.NotebookLibrary.create(context, "User journey", device, id = JOURNEY_ID)!!
        val intent = android.content.Intent(context, MainActivity::class.java)
            .putExtra("open_notebook_id", JOURNEY_ID)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        val scenario = ActivityScenario.launch<MainActivity>(intent)
        waitFor("editor.canvas", "打開筆記之後看不到畫布", 30_000)
        compose.waitForIdle()
        return scenario
    }

    private fun deleteJourneyNotebook() {
        val lib = com.kairumo.padnote.library.NotebookLibrary
        java.io.File(lib.directory(context), "$JOURNEY_ID.${lib.EXTENSION}").deleteRecursively()
        lib.invalidateCache()
    }

    private fun strokeCount(): Int {
        for (node in compose.onAllNodesWithTag("editor.canvas").fetchSemanticsNodes()) {
            val desc = node.config.getOrNull(SemanticsProperties.ContentDescription)?.firstOrNull() ?: continue
            if (desc.startsWith("strokes:")) return desc.removePrefix("strokes:").toInt()
        }
        fail("畫布沒有回報筆畫數（strokes:N）")
        error("unreachable")
    }

    /**
     * 在畫布中段橫著畫（或擦）一筆。
     *
     * 走系統的輸入管線送**手指**事件，而不是 Compose 的 `performTouchInput`：後者送出的觸控類型是
     * UNKNOWN，核心的輸入仲裁不把它當成手指 —— 畫布一筆都不收，測不到使用者實際會遇到的事。
     * 也不用 `Instrumentation.sendPointerSync`：畫面上有浮層視窗時系統會拒絕跨視窗注入。
     */
    private fun stroke(atHeight: Float) {
        val node = compose.onAllNodesWithTag("editor.canvas").onFirst().fetchSemanticsNode()
        // 用套用過縮放的邊界（連續模式的頁面被縮小過；`size` 是縮放前的版面尺寸，拿它算落點會畫到頁面外）。
        val box = node.boundsInWindow
        val window = node.positionOnScreen - node.positionInWindow
        val y = window.y + box.top + box.height * atHeight
        val x0 = window.x + box.left + box.width * 0.25f
        val x1 = window.x + box.left + box.width * 0.75f
        // `input swipe` 從系統的輸入管線送出真正的觸控（手指），與使用者的手一樣經過掌拒與仲裁。
        val cmd = "input swipe ${x0.toInt()} ${y.toInt()} ${x1.toInt()} ${y.toInt()} 450"
        InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(cmd).close()
        Thread.sleep(900)
        compose.waitForIdle()
    }

    private fun expectStrokes(why: String, check: (Int) -> Boolean) {
        runCatching { compose.waitUntil(timeoutMillis = 5_000) { check(strokeCount()) } }
            .onFailure { fail("$why（現在 strokes:${strokeCount()}）") }
    }

    /** 畫一筆並確認真的多了一筆：合成觸控偶爾整段被系統吞掉，那就再畫一次（與 Apple 同一個做法）。 */
    private fun drawOneStroke(atHeight: Float): Int {
        val before = strokeCount()
        repeat(3) {
            stroke(atHeight)
            val ok = runCatching { compose.waitUntil(timeoutMillis = 3_000) { strokeCount() > before } }.isSuccess
            if (ok) {
                assertEquals("畫一筆應該只多一筆（$before → ${strokeCount()}）", before + 1, strokeCount())
                return before
            }
        }
        fail("用鋼筆畫了一筆，筆畫數沒有變（一直是 $before）")
        error("unreachable")
    }

    /**
     * 單頁、連續兩種版面各跑一次：兩條是完全獨立的畫布路徑。連續模式每次重組都把筆設定同步給引擎，
     * 單頁模式只靠 `applyInkTool` —— 拆檔後主工具列繞過它的那個 bug 只在單頁模式（手機預設）出現，
     * 平板預設是連續模式，只測一種就看不到。
     */
    private fun useDisplayMode(wire: String?) {
        val prefs = com.kairumo.padnote.profile.ProfileContext.prefs(context, "kairumo_editor").edit()
        if (wire == null) prefs.remove("pageDisplayMode") else prefs.putString("pageDisplayMode", wire)
        prefs.commit()
    }

    private fun eraserJourney() {
        launchJourneyNotebook().use {
            tap("editor.ink.pen", "工具列上找不到鋼筆")
            val before = drawOneStroke(0.42f)

            tap("editor.ink.eraser", "工具列上找不到橡皮擦")
            stroke(0.42f)
            expectStrokes("工具列選了橡皮擦，畫過那一筆應該擦掉它，而不是多畫一筆") { it <= before }
        }
    }

    @Test
    fun eraserPickedFromTheToolbarReallyErases_singlePage() {
        skipOnboarding()
        useDisplayMode("single")
        eraserJourney()
    }

    @Test
    fun eraserPickedFromTheToolbarReallyErases_continuousPages() {
        skipOnboarding()
        useDisplayMode("continuous")
        eraserJourney()
    }

    @Test
    fun customizedRadialMenuIsWhatTheMenuShows() {
        skipOnboarding()
        ToolbarSettings.resetRadial(context, tag)
        launchJourneyNotebook().use {
            tap("editor.ink.pen", "工具列上找不到鋼筆")
            val before = drawOneStroke(0.58f)

            // 設定：拿掉工具盤的第一格（出廠是鋼筆）。
            tap("editor.more", "找不到「更多」選單")
            runCatching { compose.onNodeWithTag("editor.customize_toolbar").performScrollTo() }
            tap("editor.customize_toolbar", "「更多」選單裡找不到自訂工具列")
            compose.onNodeWithTag("toolbar.scroll").performScrollToNode(hasTestTag("radial.slot.0.remove"))
            tap("radial.slot.0.remove", "自訂工具列裡找不到飛梭工具盤的槽位")
            tap("toolbar.done", "自訂工具列沒有完成鈕")

            // 叫出工具盤：拿掉的那一格不在，其餘照舊。
            tap("editor.radial_toggle", "工具列上找不到飛梭工具盤按鈕")
            waitFor("radial.eraser", "工具盤上應該還有橡皮擦")
            assertTrue("拿掉的鋼筆不該再出現在工具盤上", !exists("radial.pen"))
            assertEquals("工具盤應該剩七格", 7, ToolbarSettings.radialActions(context, tag).size)

            // 選工具盤上的橡皮擦：與工具列同一條路，真的會擦。
            tap("radial.eraser", "點不到工具盤上的橡皮擦")
            stroke(0.58f)
            expectStrokes("從飛梭工具盤選了橡皮擦，畫過那一筆應該擦掉它") { it <= before }
        }
    }
}
