package com.kairumo.padnote.screens

import android.content.Context
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.MainActivity
import org.json.JSONObject
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 畫面稽核：規格說必須有的控制項，要真的畫得出來（提案 ①，Android 端）。
 *
 * # 為什麼 Android 也要有
 *
 * `docs/conformance/screens.json` 是**一份規格兩端共用** —— Apple 端讀
 * `apple` 那半邊（`apple/UITests/ScreenAudit.swift`），這裡讀 `android`。
 * 只有一端有稽核的話，另一端就會慢慢漂走，而那正是這個專案一再發生的事。
 *
 * # 與 Apple 端的差別
 *
 * Apple 那邊還斷言「點得到」（`isHittable`），擋的是 zIndex 那種
 * 「畫得出來卻按不到」。Compose 沒有等價的單一查詢 —— `assertIsDisplayed`
 * 只看有沒有在畫面上，不看上面有沒有蓋東西。所以這裡先守「存在」那一半，
 * 遮蔽那一半記在 docs/TODO.md 的 S-263。
 *
 * # 為什麼不用釘語言
 *
 * 稽核認的是 `testTag`，不是顯示文字 —— 天生與語言無關。
 * （Apple 端要釘語言是因為**既有的**冒煙測試綁在顯示文字上。）
 */
@RunWith(AndroidJUnit4::class)
class ScreenAuditTest {

    // 用 empty rule 而不是 createAndroidComposeRule<MainActivity>()：
    // 導覽看過沒存在 SharedPreferences，要在 Activity 起來**之前**設好。
    // rule 會在 @Before 之前就把 Activity launch 起來，來不及。
    @get:Rule
    val compose = createEmptyComposeRule()

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun homeScreenRendersEveryRequiredControl() {
        audit("home", allowMissing = HOME_NOT_WIRED_YET, scrollTag = "home.scroll")
    }

    /**
     * @param scrollTag 捲動容器的 tag。`null` 代表這個畫面不是 lazy 清單
     *   （編輯器的工具列是 `FlowRow`，整排一次組合完）—— 那時候捲動不但沒用，
     *   還會把「找不到」誤報成「捲不過去」。
     * @param navigate 走到這個畫面要先做什麼。首頁是 `{}`。
     */
    @Test
    fun editorScreenRendersEveryRequiredControl() {
        audit("editor", allowMissing = EDITOR_NOT_WIRED_YET, scrollTag = null) {
            openFirstNotebook()
        }
    }

    @Test
    fun toolbarScreenRendersEveryRequiredControl() {
        audit("toolbar", allowMissing = emptySet(), scrollTag = null) {
            openFirstNotebook()
            compose.onNodeWithTag("editor.more").performClick()
            compose.waitForIdle()
            compose.onNodeWithTag("editor.customize_toolbar").performClick()
            compose.waitForIdle()
        }
    }

    /**
     * 開啟第一本筆記。
     *
     * 靠 `home.notebooks.card.<id>` 這個前綴找，不靠顯示文字 —— 文字會隨
     * 語言變，而這個稽核本來就刻意與語言無關。卡片的識別碼是 S-263 補的，
     * 在那之前整份清單只有一個 tag，根本點不到特定一本。
     */
    private fun openFirstNotebook() {
        val cards = compose.onAllNodes(
            SemanticsMatcher("testTag 以 home.notebooks.card. 開頭") { node ->
                node.config.getOrNull(SemanticsProperties.TestTag)
                    ?.startsWith("home.notebooks.card.") == true
            })
        val nodes = cards.fetchSemanticsNodes()
        assertTrue("首頁一本筆記都沒有 —— 種子資料沒建起來？", nodes.isNotEmpty())
        cards[0].performClick()
    }

    private fun audit(
        screen: String,
        allowMissing: Set<String>,
        scrollTag: String?,
        navigate: () -> Unit = {}
    ) {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            navigate()
            compose.waitForIdle()

            val required = requiredControlIds(screen)
            assertTrue(
                "核心對畫面「$screen」沒有任何必要控制項的規格 —— 畫面 id 打錯了？",
                required.isNotEmpty())

            // **一定要捲過整份清單。**
            //
            // Compose 的 LazyColumn 只組合看得見的項目 —— 沒捲到的控制項
            // 根本不在語意樹裡，不是「缺 testTag」。第一次跑只缺 1 項、
            // 第二次跑缺 13 項，同一份程式碼、同一台模擬器，差別只在捲動
            // 位置。**結果不確定的閘門會被關掉**，所以這一段不是優化。
            val missing = findMissingWhileScrolling(
                wanted = required.filterNot { it in allowMissing },
                scrollTag = scrollTag)

            assertTrue(
                buildString {
                    append("畫面「$screen」少了規格要求的控制項：\n")
                    append(missing.joinToString("\n"))
                    append("\n\n現場實際有的 testTag（最多 20 個）：\n")
                    append(presentTags().take(20).joinToString("\n"))
                    append("\n\n一個都對不上的話，多半不是缺 testTag，")
                    append("是**根本沒到這個畫面**（例如卡在首次啟動流程）。")
                },
                missing.isEmpty())
        }
    }

    /** 導覽看過沒存在 SharedPreferences —— 不設的話起始畫面取決於這台裝置之前被怎麼玩過。 */
    private fun skipOnboarding() {
        context.getSharedPreferences("kairumo_onboarding", Context.MODE_PRIVATE)
            .edit().putBoolean("seen_v1", true).commit()
    }

    private fun requiredControlIds(screen: String): List<String> {
        val text = InstrumentationRegistry.getInstrumentation().context
            .assets.open("conformance/screens.json").bufferedReader().readText()
        val entry = JSONObject(text).optJSONObject(screen) ?: return emptyList()
        val ids = entry.optJSONArray("android") ?: return emptyList()
        return (0 until ids.length()).map { ids.getString(it) }
    }

    /**
     * 從頂端捲到底，沿路把看到的 testTag 全收起來。
     *
     * 捲到不再有新的 tag 出現就停 —— 固定捲 N 次的話，清單變長時會悄悄
     * 漏掉尾巴，而那會表現成「某個控制項不見了」的假警報。
     */
    /**
     * 捲到每一個控制項那裡去看它在不在。
     *
     * **一定要捲。** Compose 的 LazyColumn 只組合看得見的項目 —— 沒捲到的
     * 控制項根本不在語意樹裡，不是「缺 testTag」。同一份程式碼、同一台
     * 模擬器，不捲的話第一次跑缺 1 項、第二次缺 13 項，差別只在起始捲動
     * 位置。**結果不確定的閘門會被關掉**，所以這一段不是優化。
     *
     * 用 `performScrollToNode` 而不是自己 `swipeUp` 迴圈：一次 swipe 會跳過
     * 好幾個項目，而被跳過的那些會在兩次檢查之間被組合又丟棄 —— 於是明明
     * 無條件渲染的 `home.notebooks.sort` 也會被判成「不見了」。
     * 這個 API 就是為 lazy 清單設計的，它會捲到節點真的被組合出來為止。
     */
    private fun findMissingWhileScrolling(wanted: List<String>, scrollTag: String?): List<String> =
        wanted.filter { id ->
            if (compose.onAllNodesWithTag(id).fetchSemanticsNodes().isNotEmpty()) return@filter false
            // 沒有捲動容器就是真的不在 —— 硬捲一個不存在的容器只會把
            // 「缺這個控制項」變成「捲不過去」，兩種訊息看起來一樣。
            if (scrollTag == null) return@filter true
            runCatching {
                compose.onNodeWithTag(scrollTag).performScrollToNode(hasTestTag(id))
            }.isFailure
        }

    /** 現場實際存在的 testTag。 */
    private fun presentTags(): List<String> =
        compose.onAllNodes(
            SemanticsMatcher.keyIsDefined(SemanticsProperties.TestTag),
            useUnmergedTree = true)
            .fetchSemanticsNodes()
            .mapNotNull { it.config.getOrNull(SemanticsProperties.TestTag) }

    private companion object {
        /**
         * 還沒接上 testTag 的控制項（棘輪）。**只准縮小。**
         *
         * 空的。`home.recordings.list` 原本在這裡 —— 它的 tag 掛在每一列
         * 錄音上，於是**沒有錄音時整個不存在**，乾淨的裝置上一定看不到。
         *
         * 2026-09-23 改成「沒有錄音時容器仍在，裡面放空狀態提示」，與
         * Apple 端一致。修的是產品不是測試：一個只在有資料時才存在的容器，
         * 對無障礙工具來說也是同一個問題。
         */
        val HOME_NOT_WIRED_YET = emptySet<String>()

        /**
         * 編輯器的棘輪。**只准縮小。**
         *
         * 與 Apple 端那一份是同一批東西、同一個理由：`insert.*` 在「更多」
         * 選單裡、`export.*` 在匯出選單裡、`text.*` 只有打字模式才有、
         * `sidebar.*` 要先展開側欄 —— 單一畫面狀態的稽核看不到它們。
         *
         * Apple 端已經有兩條測試把選單那批守住了
         * （testMoreMenuItemsAreReachable / testExportMenuItemsAreReachable）。
         * Android 這邊還沒有對應的 —— Compose 的 DropdownMenu 內容進不進
         * 語意樹還沒量過，而**沒量過就不該假設它跟 Apple 一樣**。
         * 記在 docs/TODO.md 的 S-261c。
         */
        val EDITOR_NOT_WIRED_YET = setOf(
            "editor.insert.assets",
            "editor.insert.audio",
            "editor.insert.image",
            "editor.insert.math",
            "editor.insert.chart",
            "editor.insert.table",
            "editor.insert.shape",
            "editor.insert.model3d",
            "editor.insert.theme_tools",
            "editor.customize_toolbar",
            "editor.insert.refine_sketch",
            "editor.insert.comment_pin",
            "editor.insert.collaborate",
            "editor.insert.recognize",
            "editor.insert.ai_summary",
            "editor.export.pdf",
            "editor.export.image",
            "editor.export.print",
            "editor.export.share",
            "editor.ink.clear",
            "editor.text.add_box",
            "editor.text.studio",
            "editor.text.bold",
            "editor.text.italic",
            "editor.text.underline",
            "editor.text.align_left",
            "editor.text.align_center",
            "editor.text.align_right",
            "editor.text.snap_grid",
            "editor.text.layer_forward",
            "editor.text.layer_backward",
            "editor.text.symbols",
            "editor.text.select",
            "editor.text.link",
            "editor.text.undo",
            "editor.text.redo",
            "editor.sidebar.tab.pages",
            "editor.sidebar.tab.folders",
            "editor.sidebar.list",
            "editor.sidebar.thumb_smaller",
            "editor.sidebar.thumb_larger",
        )

    }
}
