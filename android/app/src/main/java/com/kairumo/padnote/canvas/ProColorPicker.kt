package com.kairumo.padnote.canvas

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings

/**
 * 專業色票（Android）。
 *
 * 五組設計師色盤全部來自核心的 `designerPalette()` —— 顏色與組別順序都與
 * Apple 端同一份。各寫一份的話，同一個「莫蘭迪」在兩台裝置上是不同的顏色，
 * 而顏色是會落盤的資料。
 *
 * 色名走語系鍵：Apple 端原本那 40 個名字是寫死的繁體中文，日文使用者在一個
 * 已經翻成六國語系的面板裡看到一整面中文。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ProColorPicker(
    languageTag: String,
    currentHex: String?,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("proColorPicker", 420.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var picked by remember { mutableStateOf(currentHex) }
    val groups = remember { uniffi.padnote_core.designerPaletteGroups() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("pro_color")) },
        text = {
            Column(
                modifier = Modifier.height(height.value).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                for (group in groups) {
                    Text(
                        l(uniffi.padnote_core.designerPaletteGroupKey(group)),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold
                    )
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        for (entry in uniffi.padnote_core.designerPalette(group)) {
                            val color = parse(entry.hex) ?: Color.Gray
                            Box(
                                // 命中區 42dp、色塊 32dp —— 與其他色票同一套作法。
                                modifier = Modifier.size(42.dp).clickable { picked = entry.hex },
                                contentAlignment = Alignment.Center
                            ) {
                                Box(
                                    Modifier
                                        .size(32.dp)
                                        .background(color, RoundedCornerShape(6.dp))
                                        .border(
                                            if (picked == entry.hex) 3.dp else 1.dp,
                                            if (picked == entry.hex) MaterialTheme.colorScheme.primary
                                            else MaterialTheme.colorScheme.outline,
                                            RoundedCornerShape(6.dp)
                                        )
                                )
                            }
                        }
                    }
                }

                picked?.let {
                    Text(
                        "${l("hex_code")} $it",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
            // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
            DialogResizeHandle(height, "proColorPicker")
        },
        confirmButton = {
            TextButton(
                enabled = picked != null,
                onClick = { picked?.let(onPick); onDismiss() }
            ) { Text(l("confirm")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

private fun parse(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
