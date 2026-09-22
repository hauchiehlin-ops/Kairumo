package com.kairumo.padnote.screens

import android.content.Context
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.kairumo.padnote.MainActivity
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 量測工具，**不是閘門**：Compose 的 `DropdownMenu` 內容進不進語意樹？
 *
 * # 為什麼要量
 *
 * Apple 端量過同一件事，答案是「進得去，但 `.accessibilityIdentifier`
 * 不會跟進 UIKit 的 `UIAction`，只剩標籤」（S-261d）。
 *
 * **不能因此假設 Android 一樣。** Compose 的選單是自己畫的 Composable，
 * 不像 SwiftUI 那樣交給系統元件算繪 —— 很可能 `testTag` 原封不動就在。
 * 假設錯的話，會白白把十九個項目長期放在棘輪裡，而棘輪裡的東西沒有人
 * 會再看第二眼。
 *
 * 量完就知道 `EDITOR_NOT_WIRED_YET` 那一批能不能直接清掉。
 */
@RunWith(AndroidJUnit4::class)
class MenuProbeTest {

    @get:Rule
    val compose = createEmptyComposeRule()

    private val context: Context
        get() = InstrumentationRegistry.getInstrumentation().targetContext

    @Test
    fun dropdownMenuContentsAreInTheSemanticsTree() {
        context.getSharedPreferences("kairumo_onboarding", Context.MODE_PRIVATE)
            .edit().putBoolean("seen_v1", true).commit()

        ActivityScenario.launch(MainActivity::class.java).use {
            compose.waitForIdle()

            val cards = compose.onAllNodes(
                SemanticsMatcher("testTag 以 home.notebooks.card. 開頭") { node ->
                    node.config.getOrNull(SemanticsProperties.TestTag)
                        ?.startsWith("home.notebooks.card.") == true
                })
            assertTrue("首頁一本筆記都沒有", cards.fetchSemanticsNodes().isNotEmpty())
            cards[0].performClick()
            compose.waitForIdle()

            val before = allTags()
            compose.onNodeWithTag("editor.more").performClick()
            compose.waitForIdle()
            val after = allTags()

            println("【探針】開選單前 tag 數：${before.size}")
            println("【探針】開選單後 tag 數：${after.size}")
            println("【探針】新出現的：${(after - before).sorted().joinToString(", ")}")
            println(
                "【探針】用 testTag 找 editor.customize_toolbar：" +
                    compose.onAllNodesWithTag("editor.customize_toolbar")
                        .fetchSemanticsNodes().isNotEmpty())
        }
    }

    private fun allTags(): Set<String> =
        compose.onAllNodes(
            SemanticsMatcher.keyIsDefined(SemanticsProperties.TestTag),
            useUnmergedTree = true)
            .fetchSemanticsNodes()
            .mapNotNull { it.config.getOrNull(SemanticsProperties.TestTag) }
            .toSet()
}
