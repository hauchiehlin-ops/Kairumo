package com.kairumo.padnote.text

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import uniffi.padnote_core.FfiSymbolCategory
import uniffi.padnote_core.symbolCategories
import uniffi.padnote_core.symbolPalette

/**
 * 特殊符號面板（S-97）。
 *
 * # 為什麼符號表在核心
 *
 * Apple 端原本把四組符號**寫死在工具列的程式碼裡**，而核心早就有
 * `symbol_palette` —— 於是同一個「數學符號」選單，兩邊給的東西不一樣，
 * 而那是使用者會記住位置的東西（「星號在左上角第一個」）。兩端現在都讀
 * 核心那一份。
 *
 * # 為什麼是對話框不是巢狀選單
 *
 * Apple 走的是巢狀 `Menu`；Compose 的巢狀 DropdownMenu 在手機上會疊成
 * 兩層蓋住畫面，而且四十幾個符號排成一長條要捲很久。分類膠囊 + 換行的
 * 符號格子，一眼就看得完。這是白名單裡「平台原生控制項呈現差異」的那一類。
 */
@OptIn(ExperimentalLayoutApi::class, ExperimentalFoundationApi::class)
@Composable
fun SymbolPickerDialog(
    l: (String) -> String,
    onDismiss: () -> Unit,
    onPick: (String) -> Unit
) {
    val height = rememberDialogHeight("symbolPicker", 360.dp)
    var category by remember { mutableStateOf(FfiSymbolCategory.SPECIAL) }
    val categories = remember { symbolCategories() }
    val symbols = remember(category) { symbolPalette(category) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("special_symbols")) },
        text = {
            Column {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    categories.forEach { option ->
                        FilterChip(
                            selected = option == category,
                            onClick = { category = option },
                            label = {
                                Text(
                                    l(categoryKey(option)),
                                    style = MaterialTheme.typography.labelMedium,
                                    maxLines = 1
                                )
                            }
                        )
                    }
                }

                FlowRow(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(height.value)
                        .verticalScroll(rememberScrollState())
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    symbols.forEach { symbol ->
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clickable { onPick(symbol) },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(symbol, style = MaterialTheme.typography.titleMedium)
                        }
                    }
                }
                // 底部的拖曳把手：往下拖變高（S-72）。
                DialogResizeHandle(height, "symbolPicker")
            }
        },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("close")) } }
    )
}

/** 分類的語系鍵。與 Apple 的三個選單標題同一組鍵。 */
private fun categoryKey(category: FfiSymbolCategory): String = when (category) {
    FfiSymbolCategory.SPECIAL -> "special_symbols"
    FfiSymbolCategory.PUNCTUATION -> "punctuation_symbols"
    FfiSymbolCategory.MATH -> "math_symbols"
    FfiSymbolCategory.ROMAN -> "roman_symbols"
}
