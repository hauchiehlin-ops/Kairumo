package com.kairumo.padnote.image

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.fillMaxWidth
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
    onChanged: (NoteImage) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var filter by remember(image.id) { mutableStateOf(image.filterStyle) }
    var corner by remember(image.id) { mutableStateOf(image.cornerRadius) }
    var shadow by remember(image.id) { mutableStateOf(image.hasShadow) }
    var border by remember(image.id) { mutableStateOf(image.hasBorder) }
    var borderHex by remember(image.id) { mutableStateOf(image.borderColorHex) }
    var rotation by remember(image.id) { mutableStateOf(image.rotationDegrees) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("image_style")) },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.verticalScroll(rememberScrollState())
            ) {
                Text(l("image_filter"), style = MaterialTheme.typography.labelMedium)
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (option in ImageFilterStyle.entries) {
                        FilterChip(
                            selected = filter == option,
                            onClick = { filter = option },
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
        },
        confirmButton = {
            TextButton(onClick = {
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
            }) { Text(l("done")) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } }
    )
}

private fun parse(hex: String): Color? =
    com.kairumo.padnote.chart.ChartRenderer.parseColor(hex)?.let { Color(it) }
