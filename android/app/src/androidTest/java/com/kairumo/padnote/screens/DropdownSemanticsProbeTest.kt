package com.kairumo.padnote.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * **量測，不是閘門**：Compose 的 `DropdownMenu` 內容進不進語意樹，
 * `testTag` 會不會跟著進去？
 *
 * # 為什麼要單獨量
 *
 * Apple 端量過同一件事，答案是「項目進得去，但 `.accessibilityIdentifier`
 * 不會跟進 UIKit 的 `UIAction`，只剩標籤」（S-261d）。整整十九個項目因此
 * 被放進 [ScreenAuditTest.EDITOR_NOT_WIRED_YET] 這個棘輪裡，理由寫的是
 * 「Android 還沒量過，**沒量過就不該假設它跟 Apple 一樣**」。
 *
 * # 為什麼不用真的 App 來量
 *
 * 第一版（`MenuProbeTest`）是開 `MainActivity` 走到編輯器再開選單 ——
 * 那條路會先卡在種子資料、Activity 生命週期、native 函式庫版本這些
 * **與問題無關**的東西上。實際就是這樣：第一次跑掛在 `.so` 過期，
 * 第二次掛在「首頁一本筆記都沒有」，兩次都沒量到要量的那件事。
 *
 * 這一條用的是與 App 完全一樣的結構（`DropdownMenu` + 帶 `testTag` 的
 * `DropdownMenuItem`），但不碰任何 App 狀態。答案對就是對。
 *
 * # 量到的答案
 *
 * **帶著進去。** 所以 `EDITOR_NOT_WIRED_YET` 那一批清掉了，改成用會先
 * 打開選單的測試去看（`ScreenAuditTest.moreMenuItemsAreReachable` 等）。
 *
 * 這條留著不是因為它還是閘門，是因為**它是那個決定的依據**：哪天有人想把
 * 那些測試改回棘輪，這裡會告訴他不必。
 */
@RunWith(AndroidJUnit4::class)
class DropdownSemanticsProbeTest {

    @get:Rule
    val compose = createComposeRule()

    @Test
    fun dropdownMenuItemsKeepTheirTestTag() {
        compose.setContent {
            var open by remember { mutableStateOf(false) }
            Column {
                TextButton(
                    onClick = { open = true },
                    modifier = Modifier.testTag("probe.more")
                ) { Text("more") }
                DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                    DropdownMenuItem(
                        text = { Text("item") },
                        modifier = Modifier.testTag("probe.menu.item"),
                        onClick = {}
                    )
                }
            }
        }

        // 選單還沒開：項目本來就不該在。這一步是對照組 —— 少了它，
        // 下面那個斷言就算永遠成立也看不出來。
        compose.onNodeWithTag("probe.menu.item").assertDoesNotExist()

        compose.onNodeWithTag("probe.more").performClick()
        compose.waitForIdle()

        // **這就是要量的那一件事。**
        compose.onNodeWithTag("probe.menu.item").assertExists(
            "Compose 的 DropdownMenu 項目沒有帶著 testTag 進語意樹 —— " +
                "那 EDITOR_NOT_WIRED_YET 那一批就真的只能留在棘輪裡"
        )
    }
}
