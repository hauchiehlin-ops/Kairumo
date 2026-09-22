package com.kairumo.padnote.screens

import android.content.Context
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeUp
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

    private fun audit(screen: String, allowMissing: Set<String>, scrollTag: String) {
        skipOnboarding()
        ActivityScenario.launch(MainActivity::class.java).use {
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
     * 邊捲邊找，回傳捲到底之後仍然找不到的。
     *
     * **一定要捲。** Compose 的 LazyColumn 只組合看得見的項目 —— 沒捲到的
     * 控制項根本不在語意樹裡，不是「缺 testTag」。同一份程式碼同一台模擬器，
     * 第一次跑缺 1 項、第二次缺 13 項，差別只在捲動位置。
     * **結果不確定的閘門會被關掉**，所以這一段不是優化。
     *
     * 找到就從待找清單移除，全部找到就提早結束 —— 不必每次都捲到底。
     */
    private fun findMissingWhileScrolling(wanted: List<String>, scrollTag: String): List<String> {
        var pending = wanted.filter { compose.onAllNodesWithTag(it).fetchSemanticsNodes().isEmpty() }
        repeat(MAX_SCROLLS) {
            if (pending.isEmpty()) return emptyList()
            compose.onNodeWithTag(scrollTag).performTouchInput { swipeUp() }
            compose.waitForIdle()
            val before = pending.size
            pending = pending.filter { compose.onAllNodesWithTag(it).fetchSemanticsNodes().isEmpty() }
            // 捲了一次卻沒有任何新東西出現 —— 到底了。
            if (pending.size == before && !scrolledFurther(scrollTag)) return pending
        }
        return pending
    }

    /** 捲動之後畫面有沒有真的動。到底之後再 swipe 也不會變。 */
    private fun scrolledFurther(scrollTag: String): Boolean {
        val before = presentTags()
        compose.onNodeWithTag(scrollTag).performTouchInput { swipeUp() }
        compose.waitForIdle()
        return presentTags() != before
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
         * `home.recordings.list` 是條件顯示：`HomeScreen.kt:433` 在
         * `recordings.isEmpty()` 時畫的是空狀態提示，那個 tag 根本不存在。
         * 乾淨的模擬器上沒有錄音，所以稽核一定看不到它。
         *
         * 正解是讓稽核能表達「這個控制項要有資料才會出現」—— 規格的
         * `FfiControlSpec` 已經有 `optional` 欄位，但這一項標的是必要。
         * 要嘛把它改成 optional，要嘛讓測試先塞一筆錄音。記在 S-263。
         */
        val HOME_NOT_WIRED_YET = setOf(
            // 條件顯示：HomeScreen.kt 在 recordings.isEmpty() 時畫的是空狀態
            // 提示，這個 tag 根本不存在。乾淨的模擬器上沒有錄音。
            "home.recordings.list",
            // 這三個在筆記本區的標頭。**sort 與 rename_root 在 Apple 端也缺**
            // （見 SmokeUITests.homeNotWiredYet）—— 規格標為必要，但兩端預設
            // 都不顯示。是規格該改成 optional，還是兩端都該補？見 S-263。
            "home.notebooks.sort",
            "home.notebooks.rename_root",
            "home.notebooks.new_folder",
        )

        /** 捲動上限。到底之前就會因為「沒有新 tag」提早停，這只是保險。 */
        const val MAX_SCROLLS = 20
    }
}
