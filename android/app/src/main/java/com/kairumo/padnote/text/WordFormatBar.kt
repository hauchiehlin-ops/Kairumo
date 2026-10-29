package com.kairumo.padnote.text

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Word 式的文字格式工具列（Android）。打字工具列與文字方塊編輯面板共用這一份 ——
 * 兩處各寫一份的話，加一個功能就得改兩個地方，漏掉的那邊會安靜地少一顆按鈕。
 *
 * 控制項、色盤、字級清單與 Apple 端的 `WordToolbarView` 相同。
 */

/** 與 Office Word 相同的色彩（鍵名對 `wd_c_*`，與 Apple 端 `WordPalette` 同一組）。 */
object WordPalette {
    val themeBase = listOf(
        "#FFFFFF" to "wd_c_white", "#000000" to "wd_c_black", "#E7E6E6" to "wd_c_tan",
        "#44546A" to "wd_c_blue_gray", "#4472C4" to "wd_c_blue", "#ED7D31" to "wd_c_orange",
        "#A5A5A5" to "wd_c_gray", "#FFC000" to "wd_c_gold", "#5B9BD5" to "wd_c_sky_blue",
        "#70AD47" to "wd_c_green"
    )
    val standard = listOf(
        "#C00000" to "wd_c_dark_red", "#FF0000" to "wd_c_red", "#FFC000" to "wd_c_orange",
        "#FFFF00" to "wd_c_yellow", "#92D050" to "wd_c_light_green", "#00B050" to "wd_c_green",
        "#00B0F0" to "wd_c_light_blue", "#0070C0" to "wd_c_blue", "#002060" to "wd_c_dark_blue",
        "#7030A0" to "wd_c_purple"
    )
    val highlight = listOf(
        "#FFFF00" to "wd_c_yellow", "#00FF00" to "wd_c_bright_green", "#00FFFF" to "wd_c_turquoise",
        "#FF00FF" to "wd_c_pink", "#0000FF" to "wd_c_blue",
        "#FF0000" to "wd_c_red", "#000080" to "wd_c_dark_blue", "#008080" to "wd_c_teal",
        "#008000" to "wd_c_green", "#800080" to "wd_c_violet",
        "#800000" to "wd_c_dark_red", "#808000" to "wd_c_dark_yellow", "#808080" to "wd_c_gray_50",
        "#C0C0C0" to "wd_c_gray_25", "#000000" to "wd_c_black"
    )

    private fun mix(hex: String, target: Double, amount: Double): String {
        val v = hex.removePrefix("#").toLong(16)
        val comps = listOf((v shr 16) and 0xFF, (v shr 8) and 0xFF, v and 0xFF).map { it.toDouble() }
        val out = comps.map { Math.round(it + (target - it) * amount).toInt() }
        return String.format("#%02X%02X%02X", out[0], out[1], out[2])
    }

    /** 佈景主題色彩的六列：基準色、較淺 80/60/40%、較深 25/50%（白只變深、黑只變淺）。 */
    fun themeGrid(l: (String) -> String): List<List<Pair<String, String>>> {
        val rows = mutableListOf(themeBase.map { it.first to l(it.second) })
        for (step in 0 until 5) {
            rows += themeBase.map { (hex, key) ->
                val name = l(key)
                when {
                    hex == "#FFFFFF" -> {
                        val pct = listOf(0.05, 0.15, 0.25, 0.35, 0.5)[step]
                        mix(hex, 0.0, pct) to fmt(l("wd_tint_darker"), name, pct)
                    }
                    hex == "#000000" -> {
                        val pct = listOf(0.5, 0.35, 0.25, 0.15, 0.05)[step]
                        mix(hex, 255.0, pct) to fmt(l("wd_tint_lighter"), name, pct)
                    }
                    step < 3 -> {
                        val pct = listOf(0.8, 0.6, 0.4)[step]
                        mix(hex, 255.0, pct) to fmt(l("wd_tint_lighter"), name, pct)
                    }
                    else -> {
                        val pct = listOf(0.25, 0.5)[step - 3]
                        mix(hex, 0.0, pct) to fmt(l("wd_tint_darker"), name, pct)
                    }
                }
            }
        }
        return rows
    }

    private fun fmt(pattern: String, name: String, pct: Double): String {
        var out = pattern
        for (arg in listOf(name, "${Math.round(pct * 100)}%")) {
            out = out.replaceFirst("%@", arg)
        }
        return out
    }
}

/** Word 的字級清單（下拉、以及放大／縮小逐級跳動的依據）。與 Apple 端相同。 */
val WORD_FONT_SIZES = listOf(8f, 9f, 10f, 10.5f, 11f, 12f, 14f, 16f, 18f, 20f, 22f, 24f, 26f, 28f, 36f, 48f, 72f)

fun wordGrowFontSize(size: Float): Float =
    WORD_FONT_SIZES.firstOrNull { it > size + 0.01f } ?: minOf(400f, (size / 10f).toInt() * 10f + 10f)

fun wordShrinkFontSize(size: Float): Float {
    if (size > 72.01f) return maxOf(72f, Math.ceil(size / 10.0).toFloat() * 10f - 10f)
    return WORD_FONT_SIZES.lastOrNull { it < size - 0.01f } ?: maxOf(1f, size - 1f)
}

/** 清單樣式。一個文字方塊就是「選取範圍」，清單套在方塊的每一段（開關：再按一次取消）。 */
enum class WordListKind(val marker: (Int) -> String) {
    BULLET({ "• " }), NUMBERED({ n -> "$n. " }), CHECKLIST({ "☐ " });

    fun matches(line: String): Boolean = when (this) {
        BULLET -> line.startsWith("• ")
        CHECKLIST -> line.startsWith("☐ ") || line.startsWith("☑ ") || line.startsWith("☒ ")
        NUMBERED -> existingMarkerEnd(line)?.let { line[0].isDigit() } == true
    }

    fun toggle(text: String): String {
        if (text.isEmpty()) return marker(1)
        val lines = text.split("\n")
        val content = lines.filter { it.isNotBlank() }
        val allApplied = content.isNotEmpty() && content.all { matches(it) }
        var number = 0
        return lines.joinToString("\n") { line ->
            val body = existingMarkerEnd(line)?.let { line.substring(it) } ?: line
            if (allApplied || line.isBlank()) body
            else {
                number++
                marker(number) + body
            }
        }
    }

    companion object {
        /** 段落開頭既有清單符號的結尾位置。編號最多三位數 —— 「2024. 年度」的年份不是編號。 */
        fun existingMarkerEnd(line: String): Int? {
            for (m in listOf("• ", "☐ ", "☑ ", "☒ ")) if (line.startsWith(m)) return m.length
            var i = 0
            while (i < line.length && line[i] in '0'..'9') i++
            if (i in 1..3 && i + 1 < line.length && line[i] == '.' && line[i + 1] == ' ') return i + 2
            return null
        }
    }
}

/** 工具列送出的動作。字元格式依範圍套用；段落格式（對齊、縮排、行距、清單）作用在整個方塊。 */
/** 文字醒目提示的預設色（Word 的黃色）。飛梭工具盤的螢光筆對文字方塊套的也是這個色。 */
const val TEXT_HIGHLIGHT_DEFAULT_HEX = "#FFFF00"

sealed interface WordFormatAction {
    data class Char(val edit: TextCharStyle) : WordFormatAction
    data class Align(val raw: String) : WordFormatAction
    data class Indent(val delta: Float) : WordFormatAction
    data class LineSpacing(val multiple: Float) : WordFormatAction
    data class ToggleList(val kind: WordListKind) : WordFormatAction
    data object ClearFormatting : WordFormatAction
}

private const val INDENT_STEP = 24f

/**
 * 把動作套到方塊上。回傳游標處要留給下一個字的格式（範圍是 `Caret` 時），否則 null。
 */
fun applyWordFormat(box: TextBox, action: WordFormatAction, scope: TextFormatScope): TextCharStyle? {
    when (action) {
        is WordFormatAction.Char -> when (scope) {
            is TextFormatScope.Selection -> RichText.apply(box, action.edit, scope.start, scope.end)
            is TextFormatScope.Caret -> return action.edit
            TextFormatScope.WholeBox -> RichText.applyToWholeBox(box, action.edit)
        }
        is WordFormatAction.Align -> box.alignment = action.raw
        is WordFormatAction.Indent -> {
            val next = ((box.paragraphIndent ?: 0f) + action.delta).coerceIn(0f, maxOf(0f, box.width - 60f))
            box.paragraphIndent = next.takeIf { it > 0f }
        }
        is WordFormatAction.LineSpacing -> {
            // 一行的自然高度約為字級 × 1.2；lineSpacing 存的是額外的點數（與 Apple 同義）。
            val extra = box.fontSize * 1.2f * (action.multiple - 1f)
            box.lineSpacing = extra.takeIf { it > 0.01f }
        }
        is WordFormatAction.ToggleList -> {
            val old = box.text
            box.text = action.kind.toggle(old)
            RichText.adjustRunsLineByLine(box, old)
        }
        WordFormatAction.ClearFormatting -> {
            box.alignment = "left"
            box.lineSpacing = null
            box.paragraphIndent = null
            when (scope) {
                is TextFormatScope.Selection -> RichText.clearOverrides(box, scope.start, scope.end)
                is TextFormatScope.Caret -> Unit
                TextFormatScope.WholeBox -> {
                    box.fontSize = 15f
                    box.fontFamily = null
                    box.bold = false
                    box.italic = false
                    box.underline = false
                    box.strikethrough = false
                    box.textColorHex = "#000000"
                    box.runs = null
                }
            }
        }
    }
    return null
}

/** 工具列按鈕要顯示的狀態（選取文字的格式，或方塊的格式）。 */
data class WordFormatState(
    val style: ResolvedCharStyle,
    val alignment: String,
    val paragraphIndent: Float,
    val lineSpacingMultiple: Float,
    val activeList: WordListKind?
) {
    companion object {
        fun of(box: TextBox, style: ResolvedCharStyle): WordFormatState {
            val lines = box.text.split("\n").filter { it.isNotBlank() }
            return WordFormatState(
                style = style,
                alignment = box.alignment,
                paragraphIndent = box.paragraphIndent ?: 0f,
                lineSpacingMultiple = 1f + (box.lineSpacing ?: 0f) / maxOf(1f, box.fontSize * 1.2f),
                activeList = WordListKind.entries.firstOrNull { k -> lines.isNotEmpty() && lines.all { k.matches(it) } }
            )
        }
    }
}

/**
 * Word 格式控制項。**直接發在呼叫端的 FlowRow／Row 裡**（不包自己的容器），
 * 工具列空間不夠時才能逐顆換行，而不是整條被擠扁。
 */
@Composable
fun WordFormatControls(
    state: WordFormatState,
    l: (String) -> String,
    /** 「其他色彩…」開的色相環對話框要用的語系。 */
    languageTag: String,
    /** 測試識別碼的前綴。工具列與編輯面板同時在畫面上時，兩組識別碼不能重複。 */
    tagPrefix: String = "editor.text",
    onAction: (WordFormatAction) -> Unit
) {
    var lastFontColor by rememberSaveable { mutableStateOf("#C00000") }
    var lastHighlight by rememberSaveable { mutableStateOf(TEXT_HIGHLIGHT_DEFAULT_HEX) }
    var sizeMenu by remember { mutableStateOf(false) }
    var familyMenu by remember { mutableStateOf(false) }
    var colorMenu by remember { mutableStateOf(false) }
    var highlightMenu by remember { mutableStateOf(false) }
    var spacingMenu by remember { mutableStateOf(false) }
    var customColorDialog by remember { mutableStateOf(false) }
    // 最近使用的字型色彩（與 Apple 一樣最多十個，逗號串起來）。
    var recentColors by rememberSaveable { mutableStateOf("") }
    val style = state.style

    fun char(edit: TextCharStyle) = onAction(WordFormatAction.Char(edit))
    fun pickFontColor(hex: String) {
        lastFontColor = hex
        recentColors = (listOf(hex.uppercase()) + recentColors.split(",").filter { it.isNotEmpty() && !it.equals(hex, true) })
            .take(10).joinToString(",")
        char(TextCharStyle(textColorHex = hex))
    }
    // 識別碼寫成完整字面值（畫面對照閘門掃的是原始碼裡的字串），面板裡再換成自己的前綴。
    fun tag(id: String) = if (tagPrefix == "editor.text") id else id.replaceFirst("editor.text", tagPrefix)

    // 字型
    Box {
        TextButton(onClick = { familyMenu = true }, modifier = Modifier.testTag(tag("editor.text.font_family"))) {
            Text("${style.fontFamily ?: l("font_system")} ▾", maxLines = 1)
        }
        DropdownMenu(expanded = familyMenu, onDismissRequest = { familyMenu = false }) {
            val families = listOf(null to l("font_system_default"), "sans-serif" to "Sans-serif",
                "serif" to l("font_serif"), "monospace" to l("font_mono"), "cursive" to "Cursive")
            for ((family, label) in families) {
                DropdownMenuItem(
                    text = { Text((if (style.fontFamily == family) "✓ " else "") + label) },
                    onClick = { familyMenu = false; char(TextCharStyle(fontFamily = family ?: "")) }
                )
            }
        }
    }

    // 字級：縮小 / 下拉 / 放大（與 Word 相同，逐級跳動）
    TextButton(
        onClick = { char(TextCharStyle(fontSize = wordShrinkFontSize(style.fontSize))) },
        modifier = Modifier.testTag(tag("editor.text.shrink_font")).semantics { contentDescription = l("wd_shrink_font") }
    ) { Text("A↓") }
    Box {
        TextButton(
            onClick = { sizeMenu = true },
            modifier = Modifier.testTag(tag("editor.text.font_size")).semantics { contentDescription = l("font_size") }
        ) { Text("${formatSize(style.fontSize)} ▾") }
        DropdownMenu(expanded = sizeMenu, onDismissRequest = { sizeMenu = false }) {
            for (size in WORD_FONT_SIZES) {
                DropdownMenuItem(
                    text = { Text((if (kotlin.math.abs(size - style.fontSize) < 0.01f) "✓ " else "") + formatSize(size)) },
                    onClick = { sizeMenu = false; char(TextCharStyle(fontSize = size)) }
                )
            }
        }
    }
    TextButton(
        onClick = { char(TextCharStyle(fontSize = wordGrowFontSize(style.fontSize))) },
        modifier = Modifier.testTag(tag("editor.text.grow_font")).semantics { contentDescription = l("wd_grow_font") }
    ) { Text("A↑") }

    // B / I / U / S
    ToggleGlyph("B", style.bold, l("font_bold"), tag("editor.text.bold"), fontWeight = FontWeight.Bold) {
        char(TextCharStyle(bold = !style.bold))
    }
    ToggleGlyph("I", style.italic, l("font_italic"), tag("editor.text.italic"), fontStyle = FontStyle.Italic) {
        char(TextCharStyle(italic = !style.italic))
    }
    ToggleGlyph("U", style.underline, l("text_underline"), tag("editor.text.underline"), decoration = TextDecoration.Underline) {
        char(TextCharStyle(underline = !style.underline))
    }
    ToggleGlyph("S", style.strikethrough, l("text_strikethrough"), tag("editor.text.strikethrough"), decoration = TextDecoration.LineThrough) {
        char(TextCharStyle(strikethrough = !style.strikethrough))
    }

    // 字型色彩（分割按鈕：左半套用上次的顏色，右半開色盤）
    Box {
        SplitColorButton(
            glyph = "A", barHex = lastFontColor, description = l("wd_font_color"), tag = tag("editor.text.font_color"),
            onApplyLast = { char(TextCharStyle(textColorHex = lastFontColor)) },
            onOpen = { colorMenu = true }
        )
        DropdownMenu(expanded = colorMenu, onDismissRequest = { colorMenu = false }) {
            Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    "■ ${l("wd_color_automatic")}",
                    modifier = Modifier.clickable { colorMenu = false; char(TextCharStyle(textColorHex = "#000000")) }.padding(4.dp)
                )
                Text(l("wd_theme_colors"), style = MaterialTheme.typography.labelSmall)
                for (row in WordPalette.themeGrid(l)) {
                    SwatchRow(row, style.textColorHex) { hex -> colorMenu = false; pickFontColor(hex) }
                }
                Text(l("wd_standard_colors"), style = MaterialTheme.typography.labelSmall)
                SwatchRow(WordPalette.standard.map { it.first to l(it.second) }, style.textColorHex) { hex ->
                    colorMenu = false; pickFontColor(hex)
                }
                val recent = recentColors.split(",").filter { it.isNotEmpty() }
                if (recent.isNotEmpty()) {
                    Text(l("recent_colors"), style = MaterialTheme.typography.labelSmall)
                    SwatchRow(recent.map { it to it }, style.textColorHex) { hex -> colorMenu = false; pickFontColor(hex) }
                }
                // 其他色彩：Word 的「其他色彩…」。用手寫筆刷那一個色相環，兩處調色手感一致。
                Text(
                    "🎨 ${l("wd_more_colors")}",
                    modifier = Modifier
                        .clickable { colorMenu = false; customColorDialog = true }
                        .padding(4.dp)
                        .testTag(tag("editor.text.more_colors"))
                )
            }
        }
    }

    if (customColorDialog) {
        com.kairumo.padnote.canvas.ProColorWheelDialog(
            languageTag = languageTag,
            initialHex = style.textColorHex,
            onPick = { hex -> customColorDialog = false; pickFontColor(hex) },
            onDismiss = { customColorDialog = false }
        )
    }

    // 文字醒目提示（套在字上，不是方塊底色）
    Box {
        SplitColorButton(
            glyph = "▍", barHex = lastHighlight, description = l("wd_text_highlight"), tag = tag("editor.text.highlight"),
            onApplyLast = { char(TextCharStyle(highlightHex = lastHighlight)) },
            onOpen = { highlightMenu = true }
        )
        DropdownMenu(expanded = highlightMenu, onDismissRequest = { highlightMenu = false }) {
            Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(l("wd_text_highlight"), style = MaterialTheme.typography.labelSmall)
                for (row in WordPalette.highlight.chunked(5)) {
                    SwatchRow(row.map { it.first to l(it.second) }, style.highlightHex ?: "", size = 28) { hex ->
                        highlightMenu = false; lastHighlight = hex; char(TextCharStyle(highlightHex = hex))
                    }
                }
                Text(
                    "⃠ ${l("no_highlight")}",
                    modifier = Modifier.clickable { highlightMenu = false; char(TextCharStyle(highlightHex = "clear")) }.padding(4.dp)
                )
            }
        }
    }

    // 段落：對齊
    ToggleGlyph("⇤", state.alignment == "left", l("align_left"), tag("editor.text.align_left")) { onAction(WordFormatAction.Align("left")) }
    ToggleGlyph("↔", state.alignment == "center", l("wd_align_center"), tag("editor.text.align_center")) { onAction(WordFormatAction.Align("center")) }
    ToggleGlyph("⇥", state.alignment == "right", l("align_right"), tag("editor.text.align_right")) { onAction(WordFormatAction.Align("right")) }

    // 縮排、行距
    TextButton(
        onClick = { onAction(WordFormatAction.Indent(-INDENT_STEP)) },
        enabled = state.paragraphIndent > 0f,
        modifier = Modifier.testTag(tag("editor.text.decrease_indent")).semantics { contentDescription = l("wd_decrease_indent") }
    ) { Text("⇠") }
    TextButton(
        onClick = { onAction(WordFormatAction.Indent(INDENT_STEP)) },
        modifier = Modifier.testTag(tag("editor.text.increase_indent")).semantics { contentDescription = l("wd_increase_indent") }
    ) { Text("⇢") }
    Box {
        TextButton(
            onClick = { spacingMenu = true },
            modifier = Modifier.testTag(tag("editor.text.line_spacing")).semantics { contentDescription = l("wd_line_spacing") }
        ) { Text("↕ ▾") }
        DropdownMenu(expanded = spacingMenu, onDismissRequest = { spacingMenu = false }) {
            for (multiple in listOf(1f, 1.15f, 1.5f, 2f, 2.5f, 3f)) {
                DropdownMenuItem(
                    text = {
                        Text((if (kotlin.math.abs(state.lineSpacingMultiple - multiple) < 0.02f) "✓ " else "") +
                            (if (multiple == 1.15f) "1.15" else multiple.toString().removeSuffix(".0")))
                    },
                    onClick = { spacingMenu = false; onAction(WordFormatAction.LineSpacing(multiple)) }
                )
            }
        }
    }

    // 清單（開關）
    ToggleGlyph("•≡", state.activeList == WordListKind.BULLET, l("bullet_list"), tag("editor.text.bullet_list")) {
        onAction(WordFormatAction.ToggleList(WordListKind.BULLET))
    }
    ToggleGlyph("1≡", state.activeList == WordListKind.NUMBERED, l("numbered_list"), tag("editor.text.numbered_list")) {
        onAction(WordFormatAction.ToggleList(WordListKind.NUMBERED))
    }
    ToggleGlyph("☐≡", state.activeList == WordListKind.CHECKLIST, l("todo_list"), tag("editor.text.todo_list")) {
        onAction(WordFormatAction.ToggleList(WordListKind.CHECKLIST))
    }

    // 清除所有格式設定
    TextButton(
        onClick = { onAction(WordFormatAction.ClearFormatting) },
        modifier = Modifier.testTag(tag("editor.text.clear_format"))
    ) { Text(l("wd_clear_format")) }
}

private fun formatSize(size: Float): String =
    if (size % 1f == 0f) size.toInt().toString() else String.format("%.1f", size)

@Composable
private fun ToggleGlyph(
    glyph: String,
    active: Boolean,
    description: String,
    tag: String,
    fontWeight: FontWeight? = null,
    fontStyle: FontStyle? = null,
    decoration: TextDecoration? = null,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(6.dp)
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(36.dp)
            .background(if (active) MaterialTheme.colorScheme.primary.copy(alpha = 0.18f) else Color.Transparent, shape)
            .border(1.dp, if (active) MaterialTheme.colorScheme.primary else Color.Transparent, shape)
            .clickable(onClick = onClick)
            .semantics { contentDescription = description }
            .testTag(tag)
    ) {
        Text(
            glyph,
            fontWeight = fontWeight ?: if (active) FontWeight.Bold else FontWeight.Normal,
            fontStyle = fontStyle,
            textDecoration = decoration,
            color = if (active) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
            fontSize = 15.sp
        )
    }
}

@Composable
private fun SplitColorButton(
    glyph: String,
    barHex: String,
    description: String,
    tag: String,
    onApplyLast: () -> Unit,
    onOpen: () -> Unit
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .size(width = 34.dp, height = 36.dp)
                .clickable(onClick = onApplyLast)
                .semantics { contentDescription = description }
                .testTag(tag)
                .padding(top = 4.dp)
        ) {
            Text(glyph, fontWeight = FontWeight.Bold, fontSize = 15.sp)
            Spacer(Modifier.height(1.dp))
            Box(Modifier.size(width = 18.dp, height = 4.dp).background(parseColor(barHex) ?: Color.Red))
        }
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(width = 18.dp, height = 36.dp)
                .clickable(onClick = onOpen)
                .semantics { contentDescription = description }
                .testTag("$tag.menu")
        ) { Text("▾", fontSize = 11.sp) }
    }
}

/** 一列色塊。名稱掛在無障礙描述上（TalkBack 會唸出「藍色，較淺 40%」）。 */
@Composable
private fun SwatchRow(colors: List<Pair<String, String>>, currentHex: String, size: Int = 22, onPick: (String) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        for ((hex, name) in colors) {
            val selected = hex.equals(currentHex, ignoreCase = true)
            Box(
                Modifier
                    .size(size.dp)
                    .background(parseColor(hex) ?: Color.Transparent, RoundedCornerShape(3.dp))
                    .border(
                        if (selected) 2.dp else 0.5.dp,
                        if (selected) MaterialTheme.colorScheme.primary else Color.Gray.copy(alpha = 0.4f),
                        RoundedCornerShape(3.dp)
                    )
                    .clickable { onPick(hex) }
                    .semantics { contentDescription = name }
            )
        }
    }
    Spacer(Modifier.width(0.dp))
}
