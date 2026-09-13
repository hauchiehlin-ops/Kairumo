package com.kairumo.padnote.text

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings

/**
 * 文字方塊的編輯面板（Android）。
 *
 * 控制項與 Apple 端的「Word 文字編修」對齊：字級、字形、對齊、底色（含透明）、
 * 邊框、段落（行距／段距／首行／縮排）。**改了就算數**，沒有確認按鈕 ——
 * 與 Apple 的浮動面板一致。
 */
@Composable
fun TextBoxEditor(
    box: TextBox,
    languageTag: String,
    onChanged: (TextBox) -> Unit,
    onDelete: () -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var text by remember(box.id) { mutableStateOf(box.text) }
    var revision by remember(box.id) { mutableStateOf(0) }

    fun mutate(change: (TextBox) -> Unit) {
        change(box)
        revision++
        onChanged(box)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("close")) } },
        dismissButton = {
            TextButton(onClick = onDelete) { Text(l("delete")) }
        },
        title = { Text(l("text_studio")) },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                BasicTextField(
                    value = text,
                    onValueChange = {
                        text = it
                        mutate { b -> b.text = it }
                    },
                    textStyle = TextStyle(
                        fontSize = 16.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    ),
                    modifier = Modifier.fillMaxWidth()
                )

                Divider()

                // 字級
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(l("font_size"), style = MaterialTheme.typography.labelSmall)
                    for (size in listOf(12f, 16f, 20f, 28f, 36f)) {
                        FilterChip(
                            selected = box.fontSize == size && revision >= 0,
                            onClick = { mutate { it.fontSize = size } },
                            label = { Text("${size.toInt()}") }
                        )
                    }
                }

                // 對齊
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    for (raw in listOf("left", "center", "right", "justified")) {
                        FilterChip(
                            selected = box.alignment == raw && revision >= 0,
                            onClick = { mutate { it.alignment = raw } },
                            label = { Text(raw.take(1).uppercase()) }
                        )
                    }
                }

                Divider()

                // 底色。透明放在最前面：那是使用者最常想要、而原本完全做不到的一項。
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Text(l("object_background_color"), style = MaterialTheme.typography.labelSmall)
                    FilterChip(
                        selected = box.isBackgroundClear && revision >= 0,
                        onClick = { mutate { it.backgroundColorHex = "clear" } },
                        label = { Text(l("color_transparent")) }
                    )
                    for ((key, hex) in listOf(
                        "color_white" to "#FFFFFF",
                        "color_yellow" to "#FFF9C4",
                        "color_blue" to "#E3F2FD",
                        "color_green" to "#E8F5E9"
                    )) {
                        FilterChip(
                            selected = box.backgroundColorHex == hex && revision >= 0,
                            onClick = { mutate { it.backgroundColorHex = hex } },
                            label = { Text(l(key)) }
                        )
                    }
                }

                FilterChip(
                    selected = box.hasBorder && revision >= 0,
                    onClick = { mutate { it.hasBorder = !it.hasBorder } },
                    label = { Text(l("object_show_border")) }
                )

                Divider()

                // 段落
                stepperRow(l("line_spacing"), box.lineSpacing ?: 0f, 0f..24f, 2f) { v ->
                    mutate { it.lineSpacing = v }
                }
                stepperRow(l("paragraph_spacing"), box.paragraphSpacing ?: 0f, 0f..40f, 4f) { v ->
                    mutate { it.paragraphSpacing = v }
                }
                stepperRow(l("first_line_indent"), box.firstLineIndent ?: 0f, 0f..64f, 8f) { v ->
                    mutate { it.firstLineIndent = v }
                }
                stepperRow(l("paragraph_indent"), box.paragraphIndent ?: 0f, 0f..64f, 8f) { v ->
                    mutate { it.paragraphIndent = v }
                }
            }
        }
    )
}

/**
 * 一個「標籤 + 減 / 數值 / 加」的小控制項。
 *
 * 用按鈕而不是滑桿：這些值的合理範圍很小（行距 0–24pt），滑桿在那種範圍下
 * 很難精準，而且看不到目前是多少。與 Apple 端同樣的取捨。
 */
@Composable
private fun stepperRow(
    label: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    step: Float,
    onChange: (Float) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(label, style = MaterialTheme.typography.labelSmall,
             modifier = Modifier.padding(top = 6.dp))
        TextButton(
            onClick = { onChange((value - step).coerceAtLeast(range.start)) },
            enabled = value > range.start
        ) { Text("−") }
        Text("${value.toInt()}", style = MaterialTheme.typography.labelMedium,
             modifier = Modifier.padding(top = 6.dp))
        TextButton(
            onClick = { onChange((value + step).coerceAtMost(range.endInclusive)) },
            enabled = value < range.endInclusive
        ) { Text("+") }
    }
}
