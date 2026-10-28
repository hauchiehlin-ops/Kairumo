package com.kairumo.padnote.screens

import android.content.Context
import android.os.SystemClock
import android.view.InputDevice
import android.view.MotionEvent
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
     */
    private fun injectSwipe(
        scenario: ActivityScenario<MainActivity>,
        screenX0: Float,
        screenY: Float,
        screenX1: Float,
        winX0: Float,
        winY: Float,
        winX1: Float,
        durationMs: Long = 300,
        preferredToolType: Int = MotionEvent.TOOL_TYPE_STYLUS
    ) {
        val uiAutomation = InstrumentationRegistry.getInstrumentation().uiAutomation
        val downTime = SystemClock.uptimeMillis()
        val steps = 15
        val stepTime = durationMs / steps

        var activityRef: MainActivity? = null
        scenario.onActivity { activityRef = it }
        val activity = activityRef

        fun sendEvent(action: Int, currScreenX: Float, currWinX: Float, eventTime: Long) {
            val props = arrayOf(MotionEvent.PointerProperties().apply {
                id = 0
                toolType = preferredToolType
            })
            val winCoords = arrayOf(MotionEvent.PointerCoords().apply {
                x = currWinX
                y = winY
                pressure = 1.0f
                size = 1.0f
                touchMajor = 10.0f
                touchMinor = 10.0f
            })
            val winEvent = MotionEvent.obtain(
                downTime, eventTime, action, 1, props, winCoords,
                0, 0, 1.0f, 1.0f, 0, 0,
                InputDevice.SOURCE_TOUCHSCREEN, 0
            )

            if (activity != null) {
                InstrumentationRegistry.getInstrumentation().runOnMainSync {
                    activity.dispatchTouchEvent(winEvent)
                }
            } else {
                val screenCoords = arrayOf(MotionEvent.PointerCoords().apply {
                    x = currScreenX
                    y = screenY
                    pressure = 1.0f
                    size = 1.0f
                    touchMajor = 10.0f
                    touchMinor = 10.0f
                })
                val screenEvent = MotionEvent.obtain(
                    downTime, eventTime, action, 1, props, screenCoords,
                    0, 0, 1.0f, 1.0f, 0, 0,
                    InputDevice.SOURCE_TOUCHSCREEN, 0
                )
                runCatching { uiAutomation.injectInputEvent(screenEvent, true) }
                screenEvent.recycle()
            }
            winEvent.recycle()
        }

        sendEvent(MotionEvent.ACTION_DOWN, screenX0, winX0, downTime)
        for (i in 1..steps) {
            Thread.sleep(stepTime)
            val currTime = SystemClock.uptimeMillis()
            val currScreenX = screenX0 + (screenX1 - screenX0) * (i.toFloat() / steps)
            val currWinX = winX0 + (winX1 - winX0) * (i.toFloat() / steps)
            sendEvent(MotionEvent.ACTION_MOVE, currScreenX, currWinX, currTime)
        }
        sendEvent(MotionEvent.ACTION_UP, screenX1, winX1, SystemClock.uptimeMillis())
    }

    private fun stroke(
        scenario: ActivityScenario<MainActivity>,
        atHeight: Float,
        toolType: Int = MotionEvent.TOOL_TYPE_STYLUS
    ) {
        val node = compose.onAllNodesWithTag("editor.canvas").onFirst().fetchSemanticsNode()
        // 用套用過縮放的邊界（連續模式的頁面被縮小過；`size` 是縮放前的版面尺寸，拿它算落點會畫到頁面外）。
        val box = node.boundsInWindow
        val window = node.positionOnScreen - node.positionInWindow
        val screenY = window.y + box.top + box.height * atHeight
        val screenX0 = window.x + box.left + box.width * 0.25f
        val screenX1 = window.x + box.left + box.width * 0.75f
        val winY = box.top + box.height * atHeight
        val winX0 = box.left + box.width * 0.25f
        val winX1 = box.left + box.width * 0.75f

        injectSwipe(scenario, screenX0, screenY, screenX1, winX0, winY, winX1, preferredToolType = toolType)

        Thread.sleep(500)
        compose.waitForIdle()
    }

    private fun expectStrokes(why: String, check: (Int) -> Boolean) {
        runCatching { compose.waitUntil(timeoutMillis = 5_000) { check(strokeCount()) } }
            .onFailure { fail("$why（現在 strokes:${strokeCount()}）") }
    }

    /** 畫一筆並確認真的多了一筆：合成觸控偶爾整段被系統吞掉，那就再畫一次（與 Apple 同一個做法）。 */
    private fun drawOneStroke(scenario: ActivityScenario<MainActivity>, atHeight: Float): Int {
        val before = strokeCount()
        val toolTypes = listOf(MotionEvent.TOOL_TYPE_STYLUS, MotionEvent.TOOL_TYPE_FINGER)
        for (tool in toolTypes) {
            stroke(scenario, atHeight, tool)
            val ok = runCatching { compose.waitUntil(timeoutMillis = 3_000) { strokeCount() > before } }.isSuccess
            if (ok) {
                assertEquals("畫一筆應該只多一筆（$before → ${strokeCount()}）", before + 1, strokeCount())
                return before
            }
        }

        // 後備手段：走底層 input swipe 命令
        val node = compose.onAllNodesWithTag("editor.canvas").onFirst().fetchSemanticsNode()
        val box = node.boundsInWindow
        val window = node.positionOnScreen - node.positionInWindow
        val y = (window.y + box.top + box.height * atHeight).toInt()
        val x0 = (window.x + box.left + box.width * 0.25f).toInt()
        val x1 = (window.x + box.left + box.width * 0.75f).toInt()
        val cmd = "input swipe $x0 $y $x1 $y 300"
        runCatching {
            InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand(cmd).use { pfd ->
                java.io.FileInputStream(pfd.fileDescriptor).bufferedReader().readText()
            }
        }
        Thread.sleep(600)
        compose.waitForIdle()
        if (strokeCount() > before) {
            assertEquals("畫一筆應該只多一筆（$before → ${strokeCount()}）", before + 1, strokeCount())
            return before
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
        launchJourneyNotebook().use { scenario ->
            tap("editor.ink.pen", "工具列上找不到鋼筆")
            val before = drawOneStroke(scenario, 0.42f)

            tap("editor.ink.eraser", "工具列上找不到橡皮擦")
            stroke(scenario, 0.42f)
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
        launchJourneyNotebook().use { scenario ->
            tap("editor.ink.pen", "工具列上找不到鋼筆")
            val before = drawOneStroke(scenario, 0.58f)

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
            stroke(scenario, 0.58f)
            expectStrokes("從飛梭工具盤選了橡皮擦，畫過那一筆應該擦掉它") { it <= before }
        }
    }
}
