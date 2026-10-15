package com.kairumo.padnote.text

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.sp
import org.json.JSONArray
import org.json.JSONObject
import java.text.BreakIterator

/**
 * 逐字格式（`format-spec.md` §6.2 的 `runs`）。與 Apple 端的 `RichText.swift` 同一套規則。
 *
 * 每一段只記**與方塊預設不同**的屬性；沒寫的沿用方塊層級的值。
 * 位置以 **UTF-16 碼元**計 —— Kotlin 字串索引本來就是這個單位，與 Apple 的 `NSRange` 相同。
 * 用字元數的話，表情符號與某些泰文字會讓兩個平台算出不同的位置，格式就套錯字。
 */
data class TextCharStyle(
    val bold: Boolean? = null,
    val italic: Boolean? = null,
    val underline: Boolean? = null,
    val strikethrough: Boolean? = null,
    val fontSize: Float? = null,
    val fontFamily: String? = null,
    val textColorHex: String? = null,
    /** 文字醒目提示（字的背景色）。`"clear"` 只出現在「編輯指令」裡，表示移除。 */
    val highlightHex: String? = null
) {
    val isEmpty: Boolean get() = this == TextCharStyle()

    fun overlaid(other: TextCharStyle) = TextCharStyle(
        bold = other.bold ?: bold,
        italic = other.italic ?: italic,
        underline = other.underline ?: underline,
        strikethrough = other.strikethrough ?: strikethrough,
        fontSize = other.fontSize ?: fontSize,
        fontFamily = other.fontFamily ?: fontFamily,
        textColorHex = other.textColorHex ?: textColorHex,
        highlightHex = other.highlightHex ?: highlightHex
    )
}

data class TextStyleRun(val start: Int, val length: Int, val style: TextCharStyle) {

    /** 扁平的鍵名，與 Apple 端相同（不是 `{"style": {...}}`）。 */
    fun toJson(): JSONObject = JSONObject().apply {
        put("start", start)
        put("length", length)
        style.bold?.let { put("bold", it) }
        style.italic?.let { put("italic", it) }
        style.underline?.let { put("underline", it) }
        style.strikethrough?.let { put("strikethrough", it) }
        style.fontSize?.let { put("fontSize", it.toDouble()) }
        style.fontFamily?.let { put("fontFamily", it) }
        style.textColorHex?.let { put("textColorHex", it) }
        style.highlightHex?.let { put("highlightHex", it) }
    }

    companion object {
        fun fromJson(obj: JSONObject): TextStyleRun? {
            if (!obj.has("start") || !obj.has("length")) return null
            return TextStyleRun(
                start = obj.optInt("start"),
                length = obj.optInt("length"),
                style = TextCharStyle(
                    bold = if (obj.has("bold")) obj.optBoolean("bold") else null,
                    italic = if (obj.has("italic")) obj.optBoolean("italic") else null,
                    underline = if (obj.has("underline")) obj.optBoolean("underline") else null,
                    strikethrough = if (obj.has("strikethrough")) obj.optBoolean("strikethrough") else null,
                    fontSize = if (obj.has("fontSize")) obj.optDouble("fontSize").toFloat() else null,
                    fontFamily = if (obj.has("fontFamily")) obj.optString("fontFamily") else null,
                    textColorHex = if (obj.has("textColorHex")) obj.optString("textColorHex") else null,
                    highlightHex = if (obj.has("highlightHex")) obj.optString("highlightHex") else null
                )
            )
        }

        fun listToJson(runs: List<TextStyleRun>): JSONArray = JSONArray().apply { runs.forEach { put(it.toJson()) } }

        fun listFromJson(array: JSONArray): List<TextStyleRun>? {
            val out = (0 until array.length()).mapNotNull { i -> array.optJSONObject(i)?.let(::fromJson) }
            return out.ifEmpty { null }
        }
    }
}

/** 某個字實際呈現的格式（方塊預設 + 覆寫）。 */
data class ResolvedCharStyle(
    val bold: Boolean,
    val italic: Boolean,
    val underline: Boolean,
    val strikethrough: Boolean,
    val fontSize: Float,
    val fontFamily: String?,
    val textColorHex: String,
    val highlightHex: String?
)

/** 工具列要套用格式的範圍。 */
sealed interface TextFormatScope {
    /** 有選取文字：只改選到的字（Word 的行為）。 */
    data class Selection(val start: Int, val end: Int) : TextFormatScope
    /** 只有游標、不在詞中間：改的是接下來要打的字。 */
    data class Caret(val location: Int) : TextFormatScope
    /** 方塊被選取但沒有在打字：整個方塊。 */
    data object WholeBox : TextFormatScope
}

object RichText {

    fun base(box: TextBox) = ResolvedCharStyle(
        bold = box.bold, italic = box.italic, underline = box.underline,
        strikethrough = box.strikethrough, fontSize = box.fontSize,
        fontFamily = box.fontFamily?.takeIf { it.isNotEmpty() },
        textColorHex = box.textColorHex, highlightHex = null
    )

    fun resolve(style: TextCharStyle, base: ResolvedCharStyle) = ResolvedCharStyle(
        bold = style.bold ?: base.bold,
        italic = style.italic ?: base.italic,
        underline = style.underline ?: base.underline,
        strikethrough = style.strikethrough ?: base.strikethrough,
        fontSize = style.fontSize ?: base.fontSize,
        fontFamily = if (style.fontFamily != null) style.fontFamily.takeIf { it.isNotEmpty() } else base.fontFamily,
        textColorHex = style.textColorHex ?: base.textColorHex,
        highlightHex = (style.highlightHex ?: base.highlightHex)?.takeIf { it != "clear" }
    )

    /** 把與方塊預設相同的覆寫拿掉 —— 存下來的區段才會最少。 */
    fun pruned(style: TextCharStyle, base: ResolvedCharStyle) = TextCharStyle(
        bold = style.bold?.takeIf { it != base.bold },
        italic = style.italic?.takeIf { it != base.italic },
        underline = style.underline?.takeIf { it != base.underline },
        strikethrough = style.strikethrough?.takeIf { it != base.strikethrough },
        fontSize = style.fontSize?.takeIf { kotlin.math.abs(it - base.fontSize) >= 0.01f },
        fontFamily = style.fontFamily?.takeIf { (it.ifEmpty { null }) != base.fontFamily },
        textColorHex = style.textColorHex?.takeIf { !it.equals(base.textColorHex, ignoreCase = true) },
        highlightHex = style.highlightHex?.takeIf { it != "clear" }
    )

    fun expand(runs: List<TextStyleRun>?, length: Int): MutableList<TextCharStyle> {
        val cells = MutableList(maxOf(0, length)) { TextCharStyle() }
        for (run in runs.orEmpty()) {
            val lower = maxOf(0, run.start)
            val upper = minOf(length, run.start + maxOf(0, run.length))
            for (i in lower until upper) cells[i] = cells[i].overlaid(run.style)
        }
        return cells
    }

    fun compress(cells: List<TextCharStyle>, base: ResolvedCharStyle): List<TextStyleRun>? {
        val runs = mutableListOf<TextStyleRun>()
        var i = 0
        while (i < cells.size) {
            val style = pruned(cells[i], base)
            var j = i + 1
            while (j < cells.size && pruned(cells[j], base) == style) j++
            if (!style.isEmpty) runs += TextStyleRun(i, j - i, style)
            i = j
        }
        return runs.ifEmpty { null }
    }

    /** 夾到文字長度內。別台改了文字卻沒改區段時，區段可能超出範圍。 */
    fun normalized(box: TextBox): List<TextStyleRun>? {
        val runs = box.runs ?: return null
        if (runs.isEmpty()) return null
        return compress(expand(runs, box.text.length), base(box))
    }

    fun apply(box: TextBox, edit: TextCharStyle, start: Int, end: Int) {
        val length = box.text.length
        val cells = expand(box.runs, length)
        val lower = start.coerceIn(0, length)
        val upper = end.coerceIn(lower, length)
        for (i in lower until upper) {
            cells[i] = cells[i].overlaid(edit)
            if (edit.highlightHex == "clear") cells[i] = cells[i].copy(highlightHex = null)
        }
        box.runs = compress(cells, base(box))
    }

    /** 整個方塊：改方塊層級的值，並拿掉區段裡同一項的覆寫（否則看起來改不動）。 */
    fun applyToWholeBox(box: TextBox, edit: TextCharStyle) {
        edit.bold?.let { box.bold = it }
        edit.italic?.let { box.italic = it }
        edit.underline?.let { box.underline = it }
        edit.strikethrough?.let { box.strikethrough = it }
        edit.fontSize?.let { box.fontSize = it }
        edit.fontFamily?.let { box.fontFamily = it.ifEmpty { null } }
        edit.textColorHex?.let { box.textColorHex = it }
        val cells = expand(box.runs, box.text.length)
        for (i in cells.indices) {
            var c = cells[i]
            if (edit.bold != null) c = c.copy(bold = null)
            if (edit.italic != null) c = c.copy(italic = null)
            if (edit.underline != null) c = c.copy(underline = null)
            if (edit.strikethrough != null) c = c.copy(strikethrough = null)
            if (edit.fontSize != null) c = c.copy(fontSize = null)
            if (edit.fontFamily != null) c = c.copy(fontFamily = null)
            if (edit.textColorHex != null) c = c.copy(textColorHex = null)
            edit.highlightHex?.let { c = c.copy(highlightHex = it.takeIf { h -> h != "clear" }) }
            cells[i] = c
        }
        box.runs = compress(cells, base(box))
    }

    fun clearOverrides(box: TextBox, start: Int, end: Int) {
        val length = box.text.length
        val cells = expand(box.runs, length)
        for (i in start.coerceIn(0, length) until end.coerceIn(0, length)) cells[i] = TextCharStyle()
        box.runs = compress(cells, base(box))
    }

    /** 選取範圍第一個字的格式；只有游標時看游標前一個字。 */
    fun resolvedStyleAt(box: TextBox, start: Int, end: Int): ResolvedCharStyle {
        val length = box.text.length
        val b = base(box)
        if (length == 0) return b
        val index = if (end > start) start else start - 1
        if (index !in 0 until length) return b
        return resolve(expand(box.runs, length)[index], b)
    }

    /** 替換一段文字並讓區段跟著移動。新插入的字沿用前一個字的格式（開頭插入則沿用後一個字）。 */
    fun replace(box: TextBox, start: Int, end: Int, inserted: String) {
        val length = box.text.length
        val lower = start.coerceIn(0, length)
        val upper = end.coerceIn(lower, length)
        val cells = expand(box.runs, length)
        val inherit = when {
            lower > 0 -> cells[lower - 1]
            upper < cells.size -> cells[upper]
            else -> TextCharStyle()
        }
        val next = cells.subList(0, lower) + List(inserted.length) { inherit } + cells.subList(upper, cells.size)
        box.text = box.text.substring(0, lower) + inserted + box.text.substring(upper)
        box.runs = compress(next, base(box))
    }

    /** 文字從 `old` 變成目前的內容：共同開頭與結尾之外的那段視為一次替換。 */
    fun adjustRuns(box: TextBox, old: String) {
        if (box.runs == null || old == box.text) return
        val new = box.text
        var prefix = 0
        while (prefix < old.length && prefix < new.length && old[prefix] == new[prefix]) prefix++
        var suffix = 0
        while (suffix < old.length - prefix && suffix < new.length - prefix &&
            old[old.length - 1 - suffix] == new[new.length - 1 - suffix]) suffix++
        val probe = box.copy(text = old)
        replace(probe, prefix, old.length - suffix, new.substring(prefix, new.length - suffix))
        box.runs = probe.runs
    }

    /** 行數沒變時逐行比對 —— 清單開關在每行開頭加減符號，不能把中間各行的格式洗掉。 */
    fun adjustRunsLineByLine(box: TextBox, old: String) {
        if (box.runs == null || old == box.text) return
        val oldLines = old.split("\n")
        val newLines = box.text.split("\n")
        if (oldLines.size != newLines.size) {
            adjustRuns(box, old)
            return
        }
        val probe = box.copy(text = old)
        val starts = IntArray(oldLines.size)
        var offset = 0
        for (i in oldLines.indices) {
            starts[i] = offset
            offset += oldLines[i].length + 1
        }
        for (i in oldLines.indices.reversed()) {
            val a = oldLines[i]
            val b = newLines[i]
            if (a == b) continue
            var prefix = 0
            while (prefix < a.length && prefix < b.length && a[prefix] == b[prefix]) prefix++
            var suffix = 0
            while (suffix < a.length - prefix && suffix < b.length - prefix &&
                a[a.length - 1 - suffix] == b[b.length - 1 - suffix]) suffix++
            replace(probe, starts[i] + prefix, starts[i] + a.length - suffix, b.substring(prefix, b.length - suffix))
        }
        box.runs = probe.runs
    }

    /** 游標在一個詞的中間時那個詞的範圍（Word：游標在詞中按粗體 = 整個詞變粗）。 */
    fun wordRange(text: String, location: Int): IntRange? {
        if (location <= 0 || location >= text.length) return null
        val it = BreakIterator.getWordInstance()
        it.setText(text)
        val end = it.following(location)
        val start = it.previous()
        if (start == BreakIterator.DONE || end == BreakIterator.DONE) return null
        if (start >= location || end <= location) return null
        // 標點與空白不算詞。
        if (text.substring(start, end).none { c -> c.isLetterOrDigit() }) return null
        return start until end
    }

    /** 畫布與編輯面板共用的顯示字串。 */
    fun annotated(box: TextBox): AnnotatedString {
        val text = box.text
        val b = base(box)
        val runs = box.runs
        if (runs.isNullOrEmpty()) return AnnotatedString(text)
        val cells = expand(runs, text.length)
        return buildAnnotatedString {
            append(text)
            var i = 0
            while (i < text.length) {
                var j = i + 1
                while (j < text.length && cells[j] == cells[i]) j++
                if (!cells[i].isEmpty) addStyle(spanStyle(resolve(cells[i], b)), i, j)
                i = j
            }
        }
    }

    fun spanStyle(style: ResolvedCharStyle) = SpanStyle(
        fontSize = style.fontSize.sp,
        fontWeight = if (style.bold) FontWeight.Bold else FontWeight.Normal,
        fontStyle = if (style.italic) FontStyle.Italic else FontStyle.Normal,
        fontFamily = resolveFontFamily(style.fontFamily),
        textDecoration = when {
            style.underline && style.strikethrough ->
                TextDecoration.combine(listOf(TextDecoration.Underline, TextDecoration.LineThrough))
            style.underline -> TextDecoration.Underline
            style.strikethrough -> TextDecoration.LineThrough
            else -> TextDecoration.None
        },
        color = parseColor(style.textColorHex) ?: androidx.compose.ui.graphics.Color.Black,
        background = style.highlightHex?.let(::parseColor) ?: androidx.compose.ui.graphics.Color.Unspecified
    )
}
