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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
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
    BRUSH(ToolKind.BRUSH, "tool_brush"),
    MARKER(ToolKind.MARKER, "tool_marker"),
    HIGHLIGHTER(ToolKind.HIGHLIGHTER, "tool_highlighter"),
    PENCIL(ToolKind.PENCIL, "tool_pencil"),
    WATERCOLOR(ToolKind.WATERCOLOR, "tool_watercolor"),

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

    /**
     * 跨平台對照閘門用的識別字（核心 `ffi_screens` 的 `editor.inktools`）。
     *
     * 九支工具與 Apple 端完全對齊（鋼筆、原子筆、毛筆、麥克筆、螢光筆、鉛筆、水彩、橡皮擦、套索）。
     */
    val parityIdentifier: String
        get() = when (this) {
            FOUNTAIN_PEN -> "editor.ink.pen"
            BALLPOINT -> "editor.ink.ballpoint"
            BRUSH -> "editor.ink.brush"
            MARKER -> "editor.ink.marker"
            HIGHLIGHTER -> "editor.ink.highlighter"
            PENCIL -> "editor.ink.pencil"
            WATERCOLOR -> "editor.ink.watercolor"
            ERASER -> "editor.ink.eraser"
            LASSO -> "editor.ink.lasso"
        }

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

/**
 * 色票底下那張「紙」的顏色。
 *
 * 固定白色而不是跟著主題：它代表的是**頁面**，而頁面在深色模式下仍然是白的
 * （見 PageImageRenderer 對「紙就是紙」的處理）。
 */
private val INK_SWATCH_PAPER = Color(0xFFFFFFFF)

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
    modifier: Modifier = Modifier,
    onOpenColorWheel: (() -> Unit)? = null
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
                label = { Text(LocalizationStrings.localized(option.labelKey, languageTag)) },
                modifier = Modifier.testTag(option.parityIdentifier)
            )
        }

        // 擦除與套索都不需要顏色 —— 留著只會讓使用者以為可以擦成某個顏色，
        // 或是以為選取會被染色。
        if (!tool.isEraser && !tool.isLasso) {
            // 六顆色票包成**一個** FlowRow 子項（工作項 S-64）。
            //
            // 原本它們是與筆刷晶片並列的獨立子項，於是 FlowRow 會把前幾顆
            // 塞進上一排的空隙、剩下的換行 —— 同一組顏色被拆在兩排，
            // 看起來不像一組。整組一起換行才讀得出「這是調色盤」。
            Row(
                horizontalArrangement = Arrangement.spacedBy(6.dp),
                modifier = Modifier.testTag("editor.ink.palette")
            ) {
            for ((hex, color, nameKey) in inkPalette) {
                val selected = colorHex == hex
                // 色票畫在「紙」上（工作項 S-64）。
                //
                // 墨黑是 #1C1F24，深色模式的卡片底是 #1C1E1E —— 兩者差不到
                // 一個色階，那顆色票在深色模式下**整個看不見**。
                //
                // 加白框不只是為了看得見：墨色本來就是「畫在紙上的顏色」，
                // 襯在深色介面上看到的根本不是它在頁面上的樣子。襯一張紙，
                // 兩個問題一起解決。
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(INK_SWATCH_PAPER)
                        .padding(3.dp)
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
            if (onOpenColorWheel != null) {
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(INK_SWATCH_PAPER)
                        .padding(2.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .border(1.dp, MaterialTheme.colorScheme.outlineVariant, CircleShape)
                        .clickable { onOpenColorWheel() },
                    contentAlignment = Alignment.Center
                ) {
                    Text("🎨", fontSize = 12.sp)
                }
            }
            }
        }

        Slider(
            value = width,
            onValueChange = onWidthChange,
            valueRange = inkWidthRange,
            modifier = Modifier.size(width = 120.dp, height = 32.dp).testTag("editor.ink.width")
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
                            Modifier.border(1.5.dp, MaterialTheme.colorScheme.outline, CircleShape)
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
        InkTool.BALLPOINT -> 0.65f
        InkTool.PENCIL -> 1.3f
        InkTool.FOUNTAIN_PEN -> 1.1f
        InkTool.BRUSH -> 2.2f
        InkTool.MARKER -> 2.8f
        InkTool.HIGHLIGHTER -> 3.8f
        InkTool.WATERCOLOR -> 2.4f
        InkTool.ERASER -> 3.0f
        // 套索不畫東西，預覽點沒有意義；給 1.0 讓它顯示成一個中性的點。
        InkTool.LASSO -> 1.0f
    }
    return (width * scale).coerceIn(6f, 22f)
}
