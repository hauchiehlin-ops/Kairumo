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
import androidx.compose.ui.test.performScrollTo
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
        audit("toolbar", allowMissing = emptySet(), scrollTag = "toolbar.scroll") {
            openFirstNotebook()
            compose.onNodeWithTag("editor.more").performClick()
            compose.waitForIdle()
            // **點之前一定要捲過去。**
            //
            // 「更多」選單有二十幾項，在矮螢幕上放不下。節點**在**語意樹
            // 裡（所以 `moreMenuItemsAreReachable` 是綠的 —— 它只問「在不
            // 在」），但它被畫在選單的可視範圍外，點下去等於沒點：對話框
            // 不會開，接著這個畫面的十五個控制項全部找不到。
            //
            // 320x640（CI 模擬器的實際尺寸，沒設 device profile）可以穩定
            // 重現；一般手機的 412x915 看不出來。**這就是「本機全綠、CI 紅」
            // 的原因**，而 Gradle 主控台只印失敗訊息的第一行，所以它看起來
            // 像「只少了 toolbar.hint」—— 實際上十五項一個都沒有。
            compose.onNodeWithTag("editor.customize_toolbar")
                .performScrollTo()
                .performClick()
            compose.waitForIdle()
        }
    }

    /**
     * 「更多」選單裡的項目。
     *
     * # 為什麼可以這樣測（而 Apple 不行）
     *
     * 量過了：**Compose 的 `DropdownMenu` 項目帶著 `testTag` 進語意樹**
     * （見 `DropdownSemanticsProbeTest`）。SwiftUI 那邊不是這樣 ——
     * 項目交給 UIKit 的 `UIAction` 算繪，識別碼不會跟過去，只剩標籤
     * （S-261d），所以 Apple 端那兩條測試是用標籤找的。
     *
     * 這個差別就是為什麼這十幾項在 Android 這邊被放進棘輪放了這麼久：
     * 註解寫的是「沒量過就不該假設它跟 Apple 一樣」—— 那句話是對的，
     * 而量完的答案是「不一樣，而且是好的那一邊」。
     */
    @Test
    fun moreMenuItemsAreReachable() {
        auditSubset(MORE_MENU_ITEMS, scrollTag = null) {
            openFirstNotebook()
            compose.onNodeWithTag("editor.more").performClick()
        }
    }

    /**
     * 側欄裡的項目。展開之後它們都看得到。
     *
     * 與選單那兩條同一個道理：單一畫面狀態的稽核看不到要先互動才出現的
     * 東西，而「看不到」被記成棘輪之後就沒有人會再去看它是不是真的還缺。
     */
    @Test
    fun sidebarItemsAreReachable() {
        auditSubset(SIDEBAR_ITEMS, scrollTag = null) {
            openFirstNotebook()
            compose.onNodeWithTag("editor.sidebar_toggle").performClick()
        }
    }

    /** 匯出選單裡的四個項目。與上面同一個做法、同一個理由。 */
    @Test
    fun exportMenuItemsAreReachable() {
        auditSubset(EXPORT_MENU_ITEMS, scrollTag = null) {
            openFirstNotebook()
            compose.onNodeWithTag("editor.share").performClick()
        }
    }

    /**
     * 只檢查指定的那幾個 id，不管整份規格。
     *
     * 選單打開的時候底下的畫面還在，但**整份 editor 規格不會因此就都在**
     * （例如打字模式那一批）。合併成一條的話，失敗訊息會混著兩種完全不同
     * 的原因。
     */
    private fun auditSubset(
        ids: List<String>,
        scrollTag: String?,
        navigate: () -> Unit
    ) {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()
            navigate()
            compose.waitForIdle()

            val missing = findMissingWhileScrolling(wanted = ids, scrollTag = scrollTag)
            assertTrue(
                buildString {
                    append("選單打開之後仍然找不到這些控制項：\n")
                    append(missing.joinToString("\n"))
                    append("\n\n現場實際有的 testTag（最多 20 個）：\n")
                    append(presentTags().take(20).joinToString("\n"))
                },
                missing.isEmpty())
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
        // **一定要先捲。**
        //
        // 筆記清單在首頁的下半部，而 `LazyColumn` 只組合看得見的項目 ——
        // 在乾淨的模擬器上，種子筆記**確實建起來了，只是在摺線下面**，
        // 於是這裡找不到任何卡片。
        //
        // 原本的錯誤訊息寫的是「種子資料沒建起來？」，而那句話把人帶去
        // 查 `SeedNotebooks`（實際發生過：查了 NDK、查了 .so 版本、查了
        // 種子邏輯，全部沒問題）。上面 `audit()` 那一段早就把同一件事
        // 寫清楚了，這裡卻漏了 —— 整份稽核裡唯一沒捲的就是這一步。
        val matcher = SemanticsMatcher("testTag 以 home.notebooks.card. 開頭") { node ->
            node.config.getOrNull(SemanticsProperties.TestTag)
                ?.startsWith("home.notebooks.card.") == true
        }
        if (compose.onAllNodes(matcher).fetchSemanticsNodes().isEmpty()) {
            runCatching {
                compose.onNodeWithTag("home.scroll")
                    .performScrollToNode(matcher)
                compose.waitForIdle()
            }
        }

        val cards = compose.onAllNodes(matcher)
        val nodes = cards.fetchSemanticsNodes()
        assertTrue(
            "首頁一本筆記都沒有 —— 捲過之後仍然找不到 home.notebooks.card.*。" +
                "現場的 tag：" + presentTags().take(20).joinToString(", "),
            nodes.isNotEmpty())
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
            // **合併樹與未合併樹都要查。**
            //
            // 預設的 `onAllNodesWithTag` 查的是**合併後**的語意樹，而
            // Compose 會把一段沒有自己互動行為的內容合併進祖先節點 ——
            // 合併掉的那些，子節點的 `testTag` 就從合併樹上消失了。
            //
            // 實際踩過：自訂工具列那張對話框裡，`toolbar.scroll` 清單中的
            // 每一支筆都查得到（清單項目各自可點，不會被合併），只有
            // 那段純文字的 `toolbar.hint` 查不到 —— 而它明明無條件渲染。
            // 更糟的是這件事**會隨環境變**：本機過、CI 紅。
            //
            // 無障礙工具看的也是合併樹，所以「在不在合併樹上」本身有意義；
            // 但這份稽核問的是「這個控制項有沒有被接上」，那就該兩邊都認。
            if (compose.onAllNodesWithTag(id).fetchSemanticsNodes().isNotEmpty() ||
                compose.onAllNodesWithTag(id, useUnmergedTree = true)
                    .fetchSemanticsNodes().isNotEmpty()
            ) {
                return@filter false
            }
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
         * 「更多」選單裡的項目。選單打開之後它們**都看得到**。
         *
         * 量過了：Compose 的 `DropdownMenu` 項目帶著 `testTag` 進語意樹
         * （`DropdownSemanticsProbeTest`）。在那之前這一批被放在棘輪裡，
         * 理由是「Android 還沒量過，沒量過就不該假設它跟 Apple 一樣」——
         * 那個判斷是對的，而量完的答案是**不一樣**：Apple 的選單項目識別碼
         * 會被 UIKit 吃掉，Compose 的不會。
         */
        val MORE_MENU_ITEMS = listOf(
            "editor.insert.assets",
            "editor.insert.stickers",
            "editor.insert.audio",
            "editor.insert.audio_file",
            "editor.insert.image",
            "editor.insert.image_file",
            "editor.insert.pdf",
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
            "editor.record",
        )

        /** 匯出選單裡的四項。 */
        val EXPORT_MENU_ITEMS = listOf(
            "editor.export.pdf",
            "editor.export.image",
            "editor.export.print",
            "editor.export.share",
        )

        /**
         * **不是漏做，是畫面上本來就沒有這個東西可以摸。**
         *
         * `editor.system_back` 在 Android 上是 `BackHandler` —— 一個手勢
         * 攔截器，不是控制項，永遠不會出現在語意樹裡。它在原始碼裡用
         * `// parity: editor.system_back` 宣告過，靜態對照閘門看得到它。
         *
         * 與棘輪分開列，是因為棘輪的承諾是「總有一天會清空」，而這一項
         * 永遠不會 —— 混在一起的話，那個承諾就變成謊話。
         */
        /** 側欄展開之後才看得到的那幾項。 */
        val SIDEBAR_ITEMS = listOf(
            "editor.sidebar.tab.pages",
            "editor.sidebar.tab.folders",
            "editor.sidebar.list",
            "editor.sidebar.thumb_smaller",
            "editor.sidebar.thumb_larger",
        )

        // 宣告在棘輪**之前**：companion object 的屬性照寫的順序初始化，
        // 放在後面的話 `EDITOR_NOT_WIRED_YET` 會拿到一個空集合。
        val NOT_A_WIDGET = setOf("editor.system_back")

        /**
         * 編輯器的棘輪。**只准縮小。**
         *
         * 2026-09-23 從 19 項降到剩下的這些。清掉的那一批不是放寬標準，
         * 是**改成用會打開選單的測試去看**（`moreMenuItemsAreReachable`、
         * `exportMenuItemsAreReachable`）—— 棘輪裡的東西沒有人會再看第二眼，
         * 而那正是它們待了這麼久的原因。
         *
         * 剩下的只有一類：`editor.text.*` —— 只有打字模式才有，而且那是
         * 另一套工具列。要清掉它得先有一條「切到打字模式再稽核」的測試。
         *
         * `editor.ink.clear` 在這裡是因為它只在自訂工具列開啟後才進主列，
         * 預設是收起來的。
         */
        val EDITOR_NOT_WIRED_YET = setOf(
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
        ) + MORE_MENU_ITEMS + EXPORT_MENU_ITEMS + SIDEBAR_ITEMS + NOT_A_WIDGET


    }
}
