package com.kairumo.padnote.ink

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.ToolKind

/**
 * 筆刷、顏色與筆寬（Android）。
 *
 * # 為什麼要有
 *
 * 在此之前 Android 只有**一支固定的黑色鋼筆，連橡皮擦都選不到** ——
 * 一個只有一支筆的筆記 App 不成立。核心的 `ToolKind` 與 `add_stroke`
 * 從一開始就支援這些，缺的一直只是 UI。
 *
 * # 為什麼橡皮擦不是 ToolKind
 *
 * 核心的 `ToolKind` 是**筆刷種類**（鋼筆／原子筆／螢光筆／鉛筆），
 * 擦除是另一回事 —— 它走 `erase_stroke`，是一個動作不是一種筆。
 * 所以這裡的選單把它分開表示。
 */
enum class InkTool(val kind: ToolKind?, val labelKey: String) {
    FOUNTAIN_PEN(ToolKind.FOUNTAIN_PEN, "tool_pen"),
    BALLPOINT(ToolKind.BALL_POINT, "tool_ballpoint"),
    HIGHLIGHTER(ToolKind.HIGHLIGHTER, "tool_highlighter"),
    PENCIL(ToolKind.PENCIL, "tool_pencil"),

    /** 擦除。`kind` 為 null —— 它不是一種筆刷。 */
    ERASER(null, "tool_eraser");

    val isEraser: Boolean get() = kind == null
}

/** 一組夠用的顏色。選項太多的工具列比沒有工具列還難用。 */
val inkPalette: List<Pair<String, Color>> = listOf(
    "#000000" to Color(0xFF000000),
    "#1E6FD9" to Color(0xFF1E6FD9),
    "#D93025" to Color(0xFFD93025),
    "#1E8E3E" to Color(0xFF1E8E3E),
    "#E8710A" to Color(0xFFE8710A),
    "#9334E6" to Color(0xFF9334E6)
)

/** 筆寬可選範圍。與 Apple 端的 `StrokeWidthSlider.range` 相同。 */
val inkWidthRange: ClosedFloatingPointRange<Float> = 1f..30f

@Composable
fun InkToolbar(
    tool: InkTool,
    colorHex: String,
    width: Float,
    languageTag: String,
    onToolChange: (InkTool) -> Unit,
    onColorChange: (String) -> Unit,
    onWidthChange: (Float) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        for (option in InkTool.entries) {
            FilterChip(
                selected = tool == option,
                onClick = { onToolChange(option) },
                label = { Text(LocalizationStrings.localized(option.labelKey, languageTag)) }
            )
        }

        // 擦除時不需要顏色 —— 留著只會讓使用者以為可以擦成某個顏色。
        if (!tool.isEraser) {
            for ((hex, color) in inkPalette) {
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(color)
                        .border(
                            width = if (colorHex == hex) 3.dp else 1.dp,
                            color = if (colorHex == hex) Color(0xFF1E6FD9) else Color(0x33000000),
                            shape = CircleShape
                        )
                        .clickable { onColorChange(hex) }
                )
            }
        }

        Slider(
            value = width,
            onValueChange = onWidthChange,
            valueRange = inkWidthRange,
            modifier = Modifier.size(width = 120.dp, height = 32.dp)
        )
        // 預覽點：數字不會告訴使用者「8pt 有多粗」。
        Box(
            modifier = Modifier
                .size(22.dp),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(previewDiameter(tool, width).dp)
                    .clip(CircleShape)
                    .then(
                        if (tool.isEraser) {
                            Modifier.border(1.5.dp, Color(0xFF888888), CircleShape)
                        } else {
                            Modifier.background(
                                inkPalette.firstOrNull { it.first == colorHex }?.second
                                    ?: Color.Black
                            )
                        }
                    )
            )
        }
    }
}

/**
 * 預覽點的直徑。上限 22dp —— 真的按 30pt 畫出來會把整條工具列撐高。
 *
 * 倍率與 Apple 端的 `BrushCursor.tipScale` 一致：兩個平台顯示的粗細若不一樣，
 * 同一個設定在兩邊畫出來就會不同。
 */
internal fun previewDiameter(tool: InkTool, width: Float): Float {
    val scale = when (tool) {
        InkTool.BALLPOINT, InkTool.PENCIL -> 0.65f
        InkTool.FOUNTAIN_PEN -> 1.1f
        InkTool.HIGHLIGHTER -> 3.8f
        InkTool.ERASER -> 3.0f
    }
    return (width * scale).coerceIn(6f, 22f)
}
