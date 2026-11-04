package com.kairumo.padnote.image

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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
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
 * 圖片外觀編修：濾鏡、圓角、陰影、邊框、旋轉。
 *
 * **選項與 Apple 端的 `ImageEditControls` 對齊。** 兩邊能調的東西不一樣的話，
 * 使用者在 iPad 上調好的圖到 Android 上改不回來 —— 而那些設定是會同步的。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun ImageEditor(
    image: NoteImage,
    languageTag: String,
    onReorder: ((com.kairumo.padnote.canvas.ObjectStacking.Reorder) -> Unit)? = null,
    onChanged: (NoteImage) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit,
    /** 見 `ShapeEditDialog` 的同名參數：連續頁模式傳 false，照舊用對話框。 */
    asFloatingPanel: Boolean = true
) {

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var filter by remember(image.id) { mutableStateOf(image.filterStyle) }
    // 開啟時的樣子：濾鏡改為即時套用（與 Apple 浮動面板一致，I6），按「取消」要能還原。
    val original = remember(image.id) { image }
    var corner by remember(image.id) { mutableStateOf(image.cornerRadius) }
    var shadow by remember(image.id) { mutableStateOf(image.hasShadow) }
    var border by remember(image.id) { mutableStateOf(image.hasBorder) }
    var borderHex by remember(image.id) { mutableStateOf(image.borderColorHex) }
    var rotation by remember(image.id) { mutableStateOf(image.rotationDegrees) }

    fun applyAndClose() {
        onChanged(
            image.copy(
                filterStyle = filter,
                cornerRadius = corner,
                hasShadow = shadow,
                hasBorder = border,
                borderColorHex = borderHex,
                rotationDegrees = rotation
            )
        )
        onDismiss()
    }

    // 浮動面板（與 Apple 圖片美化面板同一套）：不再是置中的對話框蓋住圖片，
    // 面板自動擺到圖片的另一側（見 `FloatingPanel` 的避讓）。關閉鈕等同「完成」。
    val panelContent: @Composable () -> Unit = {
            Column {
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    if (onReorder != null) {
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            for (op in com.kairumo.padnote.canvas.ObjectStacking.Reorder.entries) {
                                androidx.compose.material3.AssistChip(
                                    onClick = { onReorder(op) },
                                    label = { Text(l(op.labelKey)) }
                                )
                            }
                        }
                    }

                    Text(l("image_filter"), style = MaterialTheme.typography.labelMedium)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        for (option in ImageFilterStyle.entries) {
                            FilterChip(
                                selected = filter == option,
                                onClick = {
                                    filter = option
                                    // 即時寫入：畫布與側欄縮圖馬上看得到（Apple 也是點了就套）。
                                    onChanged(image.copy(filterStyle = option))
                                },
                                label = { Text(l(option.labelKey)) }
                            )
                        }
                    }

                    Text(l("image_corner_radius"), style = MaterialTheme.typography.labelMedium)
                    Slider(
                        value = corner,
                        onValueChange = { corner = it },
                        valueRange = 0f..32f
                    )

                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        FilterChip(
                            selected = shadow,
                            onClick = { shadow = !shadow },
                            label = { Text(l("image_shadow")) }
                        )
                        FilterChip(
                            selected = border,
                            onClick = { border = !border },
                            label = { Text(l("object_show_border")) }
                        )
                    }

                    if (border) {
                        Text(l("border_color"), style = MaterialTheme.typography.labelMedium)
                        FlowRow(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            // 與形狀樣式面板同一組色 —— 同一份筆記裡兩種物件的
                            // 可選色不同，使用者會以為是兩套系統。來源在核心。
                            for (hex in uniffi.padnote_core.borderPalette().map { it.hex }) {
                                val color = parse(hex) ?: Color.Gray
                                Box(
                                    modifier = Modifier.size(38.dp).clickable { borderHex = hex },
                                    contentAlignment = Alignment.Center
                                ) {
                                    Box(
                                        Modifier.size(26.dp).background(color, CircleShape).border(
                                            if (borderHex == hex) 2.5.dp else 1.dp,
                                            if (borderHex == hex) MaterialTheme.colorScheme.primary
                                            else MaterialTheme.colorScheme.outline,
                                            CircleShape
                                        )
                                    )
                                }
                            }
                        }
                    }

                    Text(l("image_rotate"), style = MaterialTheme.typography.labelMedium)
                    Slider(
                        value = rotation,
                        onValueChange = { rotation = it },
                        valueRange = 0f..360f
                    )

                    TextButton(
                        onClick = { onDelete(); onDismiss() },
                        modifier = Modifier.fillMaxWidth()
                    ) { Text(l("delete"), color = MaterialTheme.colorScheme.error) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    TextButton(onClick = {
                        if (filter != original.filterStyle) onChanged(original)
                        onDismiss()
                    }) { Text(l("cancel")) }
                    Spacer(Modifier.weight(1f))
                    TextButton(onClick = { applyAndClose() }) { Text(l("done")) }
                }
            }
    }
    if (asFloatingPanel) {
        com.kairumo.padnote.ui.FloatingPanel(title = l("image_style"), onClose = { applyAndClose() }) { panelContent() }
    } else {
        AlertDialog(
            onDismissRequest = { applyAndClose() },
            title = { Text(l("image_style")) },
            text = {
                Column(
                    Modifier
                        .heightIn(max = 520.dp)
                        .verticalScroll(rememberScrollState())
                ) { panelContent() }
            },
            confirmButton = {}
        )
    }
}

private fun parse(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
