package com.kairumo.padnote.ink

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
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
    ERASER(null, "tool_eraser"),

    /**
     * 套索選取。`kind` 同樣為 null —— 與擦除一樣，它是一個**模式**不是一種筆。
     *
     * 放進同一個選單而不是另做一個開關：使用者心裡「筆現在會做什麼」
     * 只有一個答案，分成兩處會出現「套索開著又選了螢光筆」這種說不清的狀態。
     * Apple 端也是放在同一列工具裡。
     */
    LASSO(null, "tool_lasso");

    /** 擦除模式。**套索不算** —— 兩者都沒有 `kind`，但行為完全不同。 */
    val isEraser: Boolean get() = this == ERASER

    val isLasso: Boolean get() = this == LASSO
}

/**
 * 常用墨色。**來源是核心的 `ink_palette()`**（工作項 S-63）。
 *
 * 這一組原本寫死在這裡，Apple 端也寫死在 `NotebookEditorView`。S-62 把
 * Apple 那邊換成六個「照真筆調」的墨色之後，這裡沒有跟著換 —— 同一支
 * 「藍筆」在兩台裝置上是兩個顏色（`#1E6FD9` 對 `#214FAD`）。
 *
 * 筆畫顏色是**落盤的資料**：每一筆手寫都帶著 hex 存進筆記。使用者換裝置
 * 繼續寫，同一頁上就會出現兩種藍。所以它下沉到核心，兩邊不可能再分岔。
 *
 * `key` 是語系鍵，用來當無障礙標籤 —— 純色點沒有文字，
 * TalkBack 念出來只會是「按鈕」。
 */
val inkPalette: List<Triple<String, Color, String>> =
    uniffi.padnote_core.inkPalette().map { entry ->
        Triple(entry.hex, Color(android.graphics.Color.parseColor(entry.hex)), entry.key)
    }

/** 筆寬可選範圍。與 Apple 端的 `StrokeWidthSlider.range` 相同。 */
val inkWidthRange: ClosedFloatingPointRange<Float> = 1f..30f

@OptIn(ExperimentalLayoutApi::class)
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
    // FlowRow 而不是水平捲動的 Row。
    //
    // 捲軸在觸控上還能用，但在 320dp 寬的螢幕上最後一支筆只露出半個字，
    // 而畫面上沒有任何東西告訴使用者「右邊還有」—— 他看到的就是
    // 「只有三支筆」。Apple 端的符號面板踩過同一個坑，結論一樣：換行。
    FlowRow(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        for (option in InkTool.entries) {
            FilterChip(
                selected = tool == option,
                onClick = { onToolChange(option) },
                label = { Text(LocalizationStrings.localized(option.labelKey, languageTag)) }
            )
        }

        // 擦除與套索都不需要顏色 —— 留著只會讓使用者以為可以擦成某個顏色，
        // 或是以為選取會被染色。
        if (!tool.isEraser && !tool.isLasso) {
            for ((hex, color, nameKey) in inkPalette) {
                val selected = colorHex == hex
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(color)
                        .border(
                            width = if (selected) 3.dp else 1.dp,
                            // 主色來自主題，不要再寫死藍色 —— 寫死的那個值
                            // 是舊調色盤的藍，深色模式下也不會跟著變。
                            color = if (selected) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.outlineVariant,
                            shape = CircleShape
                        )
                        .clickable { onColorChange(hex) }
                        // 純色點沒有文字，TalkBack 念出來只會是「按鈕」。
                        .semantics {
                            contentDescription = LocalizationStrings.localized(nameKey, languageTag)
                            if (selected) stateDescription =
                                LocalizationStrings.localized("selected", languageTag)
                        }
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
        // 套索不畫東西，預覽點沒有意義；給 1.0 讓它顯示成一個中性的點。
        InkTool.LASSO -> 1.0f
    }
    return (width * scale).coerceIn(6f, 22f)
}
