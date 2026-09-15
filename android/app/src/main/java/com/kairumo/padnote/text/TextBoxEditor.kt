package com.kairumo.padnote.text

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Divider
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.CanvasRotation

/**
 * 文字方塊的編輯面板（Android）。
 *
 * 控制項與分頁結構與 Apple 端的 `WordTextStudioView` 對齊：
 * 字體／段落／樣式／符號四頁。**改了就算數**，沒有確認按鈕。
 *
 * 分頁不是裝飾：原本是一條長 Column 塞進 AlertDialog，控制項一多就超出
 * 對話框高度被裁掉 —— 與 Apple 端浮動面板原本的毛病一模一樣。
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
    var tab by remember(box.id) { mutableStateOf(0) }
    var symbolCategory by remember(box.id) { mutableStateOf(0) }

    fun mutate(change: (TextBox) -> Unit) {
        change(box)
        revision++
        onChanged(box)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("close")) } },
        dismissButton = { TextButton(onClick = onDelete) { Text(l("delete")) } },
        title = { Text(l("text_studio")) },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                // 空的時候要看得出來這裡可以打字。原本是一個沒有邊框、
                // 沒有提示字的 BasicTextField —— 畫面上就是一塊空白，
                // 使用者不會知道那是輸入框（模擬器上實際看不出來）。
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(8.dp)
                        )
                        .padding(10.dp)
                ) {
                    if (text.isEmpty()) {
                        Text(
                            l("text_placeholder"),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
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
                        cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                Divider()

                // ScrollableTabRow 而不是 TabRow：TabRow 會把寬度平均分給四個
                // 分頁，320dp 的螢幕上每個只有 80dp，「Paragraph」「Symbols」
                // 會被折成兩行（實機看到「Paragr aph」）。
                ScrollableTabRow(selectedTabIndex = tab, edgePadding = 0.dp) {
                    listOf("text_tab_font", "paragraph_style", "text_tab_style", "text_tab_symbols")
                        .forEachIndexed { index, key ->
                            Tab(
                                selected = tab == index,
                                onClick = { tab = index },
                                text = { Text(l(key), style = MaterialTheme.typography.labelSmall) }
                            )
                        }
                }

                // 對話框高度有限，內容一律可捲 —— 被裁掉的控制項等於不存在。
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 280.dp)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    when (tab) {
                        0 -> {
                            label(l("font_size"))
                            chipRow(listOf(12f, 16f, 20f, 28f, 36f).map { size ->
                                ChipSpec("${size.toInt()}", box.fontSize == size && revision >= 0) {
                                    mutate { it.fontSize = size }
                                }
                            })
                            label(l("alignment"))
                            chipRow(listOf("left", "center", "right", "justified").map { raw ->
                                ChipSpec(raw.take(1).uppercase(), box.alignment == raw && revision >= 0) {
                                    mutate { it.alignment = raw }
                                }
                            })
                            label(l("font_style"))
                            chipRow(listOf(
                                ChipSpec("B", box.bold && revision >= 0) { mutate { it.bold = !it.bold } },
                                ChipSpec("I", box.italic && revision >= 0) { mutate { it.italic = !it.italic } },
                                ChipSpec("U", box.underline && revision >= 0) { mutate { it.underline = !it.underline } },
                                ChipSpec("S", box.strikethrough && revision >= 0) { mutate { it.strikethrough = !it.strikethrough } }
                            ))
                        }

                        1 -> {
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

                        2 -> {
                            // 透明放最前面：那是使用者最常想要、原本完全做不到的一項。
                            label(l("object_background_color"))
                            chipRow(
                                listOf(
                                    ChipSpec(l("color_transparent"), box.isBackgroundClear && revision >= 0) {
                                        mutate { it.backgroundColorHex = "clear" }
                                    }
                                ) + listOf(
                                    "color_white" to "#FFFFFF",
                                    "color_yellow" to "#FFF9C4",
                                    "color_blue" to "#E3F2FD",
                                    "color_green" to "#E8F5E9"
                                ).map { (key, hex) ->
                                    ChipSpec(l(key), box.backgroundColorHex == hex && revision >= 0) {
                                        mutate { it.backgroundColorHex = hex }
                                    }
                                }
                            )

                            // 邊框開關留在編輯面板裡，不放到畫布上當無標示的小圓鈕。
                            chipRow(listOf(
                                ChipSpec(l("object_show_border"), box.hasBorder && revision >= 0) {
                                    mutate { it.hasBorder = !it.hasBorder }
                                }
                            ))

                            Divider()

                            label(l("image_rotate"))
                            rotationRow(
                                degrees = CanvasRotation.normalized(box.rotationDegrees ?: 0f),
                                resetLabel = l("reset")
                            ) { v -> mutate { it.rotationDegrees = v } }
                            Text(
                                l("rotation_free_hint"),
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                        else -> {
                            chipRow(
                                listOf("special_symbols", "punctuation_marks", "math_symbols", "roman_numerals")
                                    .mapIndexed { index, key ->
                                        ChipSpec(l(key), symbolCategory == index) { symbolCategory = index }
                                    }
                            )
                            LazyVerticalGrid(
                                columns = GridCells.Adaptive(44.dp),
                                modifier = Modifier.fillMaxWidth().heightIn(max = 180.dp)
                            ) {
                                items(SYMBOL_SETS[symbolCategory]) { symbol ->
                                    TextButton(onClick = {
                                        text += symbol
                                        mutate { it.text = text }
                                    }) { Text(symbol) }
                                }
                            }
                        }
                    }
                }
            }
        }
    )
}

/**
 * 符號表。與 Apple 端 `WordTextStudioView` 的四組**逐字相同** ——
 * 兩邊不一樣的話，同一份筆記在另一個平台就插不出同樣的符號。
 */
private val SYMBOL_SETS: List<List<String>> = listOf(
    listOf("★","☆","✓","✗","▲","▼","◆","◇","●","○","→","←","↑","↓","⇄","⇒",
           "※","§","¶","©","®","™","℃","℉","♥","♦"),
    listOf("「","」","『","』","《","》","〈","〉","【","】","〔","〕","——","……","～","·",
           "；","：","？！","“","”","‘","’"),
    listOf("±","×","÷","≠","≈","≤","≥","∑","∏","√","∫","∂","∞","∈","∉","⊂",
           "⊆","∪","∩","α","β","γ","θ","λ","π","σ","ω","Δ","Ω","°"),
    listOf("Ⅰ","Ⅱ","Ⅲ","Ⅳ","Ⅴ","Ⅵ","Ⅶ","Ⅷ","Ⅸ","Ⅹ","Ⅺ","Ⅻ",
           "ⅰ","ⅱ","ⅲ","ⅳ","ⅴ","ⅵ","ⅶ","ⅷ","ⅸ","ⅹ")
)

private data class ChipSpec(val label: String, val selected: Boolean, val onClick: () -> Unit)

@Composable
private fun label(text: String) {
    Text(text, style = MaterialTheme.typography.labelSmall)
}

/**
 * 會換行的晶片列。
 *
 * 用 FlowRow 而不是固定格寬的格線：晶片標籤長度差很多（「12」對上
 * 「Transparent」），一個格寬不可能兩邊都合適 —— 窄了長標籤在晶片裡折成兩行，
 * 寬了「12」那種短標籤會佔掉半個螢幕（兩種都在實機上看過）。
 * FlowRow 讓每個晶片各自依內容取寬度，放不下才換行。
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun chipRow(specs: List<ChipSpec>) {
    FlowRow(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        for (spec in specs) {
            FilterChip(
                selected = spec.selected,
                onClick = spec.onClick,
                label = { Text(spec.label, style = MaterialTheme.typography.labelSmall) }
            )
        }
    }
}

/** 旋轉：滑桿 + 常用角度 + 歸零。角度規則與 Apple 端共用 `CanvasRotation`。 */
@Composable
private fun rotationRow(degrees: Float, resetLabel: String, onChange: (Float) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Slider(
                value = degrees,
                onValueChange = { onChange(CanvasRotation.normalized(it)) },
                valueRange = 0f..359f,
                modifier = Modifier.weight(1f)
            )
            Text("${degrees.toInt()}°", style = MaterialTheme.typography.labelMedium,
                 modifier = Modifier.padding(top = 12.dp))
        }
        // 用會換行的格線，不是 Row。Row 不換行，320dp 螢幕上四個角度加一個
        // Reset 放不下，Reset 會被整個推出畫面外 —— 而且沒有任何視覺提示。
        chipRow(
            listOf(0f, 90f, 180f, 270f).map { angle ->
                ChipSpec("${angle.toInt()}°", false) { onChange(angle) }
            } + ChipSpec(resetLabel, false) { onChange(0f) }
        )
    }
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
