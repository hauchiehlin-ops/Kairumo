package com.kairumo.padnote.shape

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
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
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings

/**
 * 形狀的樣式編修：線條顏色、填滿顏色、線條粗細、標籤。
 *
 * **選項與 Apple 端的 `ShapeStyleSheet` 必須一致** —— 同一份筆記在兩個平台
 * 可選的顏色不同的話，一邊設好的顏色到另一邊就改不回來了。
 */
@Composable
fun ShapeStyleDialog(
    shape: NoteShape,
    languageTag: String,
    onDismiss: () -> Unit,
    onApply: (NoteShape) -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var strokeHex by remember(shape.id) { mutableStateOf(shape.strokeColorHex) }
    var fillHex by remember(shape.id) { mutableStateOf(shape.fillColorHex) }
    var lineWidth by remember(shape.id) { mutableStateOf(shape.lineWidth) }
    var label by remember(shape.id) { mutableStateOf(shape.label) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("shape_style")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (shape.acceptsText) {
                    OutlinedTextField(
                        value = label,
                        onValueChange = { label = it },
                        label = { Text(l("shape_label")) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                Text(l("stroke_color"), style = MaterialTheme.typography.labelMedium)
                Swatches(selected = strokeHex, includeClear = false) { strokeHex = it }

                // 線狀形狀沒有內部可以填。放著只會讓人以為壞了。
                if (!shape.isLinear) {
                    Text(l("fill_color"), style = MaterialTheme.typography.labelMedium)
                    Swatches(selected = fillHex, includeClear = true) { fillHex = it }
                }

                Text(l("line_width"), style = MaterialTheme.typography.labelMedium)
                Column {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        for (w in listOf(1f, 2f, 3f, 5f)) {
                            FilterChip(
                                selected = lineWidth == w,
                                onClick = { lineWidth = w },
                                label = { Text(w.toInt().toString()) }
                            )
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                onApply(
                    shape.copyShape().apply {
                        strokeColorHex = strokeHex
                        fillColorHex = fillHex
                        this.lineWidth = lineWidth
                        this.label = label
                    }
                )
                onDismiss()
            }) { Text(l("done")) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(l("cancel")) }
        }
    )
}

/** 與 Apple 端 `ShapeStyleSheet.palette` 同一組色。 */
private val PALETTE = listOf(
    "#8E8E93", "#000000", "#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE"
)

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun Swatches(
    selected: String?,
    includeClear: Boolean,
    onPick: (String?) -> Unit
) {
    FlowRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (includeClear) {
            Box(
                // 命中區 38dp、色點 26dp —— 與 Apple 端一致。純色點當命中區
                // 在手指下太小，那是文字排版面板踩過的同一個坑。
                modifier = Modifier
                    .size(38.dp)
                    .clickable { onPick(null) },
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(26.dp)
                        .background(Color.Transparent, CircleShape)
                        .border(
                            if (selected == null) 2.5.dp else 1.dp,
                            if (selected == null) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outline,
                            CircleShape
                        )
                )
            }
        }
        for (hex in PALETTE) {
            val color = ChartColor(hex) ?: Color.Gray
            Box(
                modifier = Modifier
                    .size(38.dp)
                    .clickable { onPick(hex) },
                contentAlignment = Alignment.Center
            ) {
                Box(
                    Modifier
                        .size(26.dp)
                        .background(color, CircleShape)
                        .border(
                            if (selected == hex) 2.5.dp else 1.dp,
                            if (selected == hex) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outline,
                            CircleShape
                        )
                )
            }
        }
    }
}

private fun ChartColor(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
