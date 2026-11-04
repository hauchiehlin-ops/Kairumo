package com.kairumo.padnote.table

import org.json.JSONArray
import org.json.JSONObject

/**
 * 單一儲存格的格式（仿 Office 的儲存格格式）。與 Apple `NoteTableCellStyle` 同一組鍵、同一個語意。
 *
 * **每一個欄位都可為 null，null 代表「沿用表格預設」。** JSON 只寫有設定的鍵 ——
 * 與 Apple 的 `Codable`（`encodeIfPresent`）輸出相同，兩端互讀互寫不會多出或少掉鍵。
 */
data class NoteTableCellStyle(
    val bold: Boolean? = null,
    val italic: Boolean? = null,
    val underline: Boolean? = null,
    val strikethrough: Boolean? = null,
    val fontSize: Double? = null,
    val textColorHex: String? = null,
    /** 儲存格底色。`"clear"` 為透明（蓋掉表頭底色與帶狀底色）。 */
    val fillHex: String? = null,
    /** `"left"`、`"center"`、`"right"`。 */
    val hAlign: String? = null,
    /** `"top"`、`"middle"`、`"bottom"`。 */
    val vAlign: String? = null,
    /** 文字方向：0 橫向、90 順時針、270 逆時針。 */
    val textRotation: Int? = null,
    /** 自動換行。null 與 true 相同。 */
    val wrap: Boolean? = null
) {
    val isDefault: Boolean get() = this == DEFAULT

    /** 會改變格子所需高度的設定（與 Apple `affectsMeasure` 同一個判斷）。 */
    val affectsMeasure: Boolean
        get() = bold != null || italic != null || fontSize != null ||
            (textRotation != null && textRotation != 0) || wrap == false

    fun toJson(): JSONObject = JSONObject().apply {
        bold?.let { put("bold", it) }
        italic?.let { put("italic", it) }
        underline?.let { put("underline", it) }
        strikethrough?.let { put("strikethrough", it) }
        fontSize?.let { put("fontSize", it) }
        textColorHex?.let { put("textColorHex", it) }
        fillHex?.let { put("fillHex", it) }
        hAlign?.let { put("hAlign", it) }
        vAlign?.let { put("vAlign", it) }
        textRotation?.let { put("textRotation", it) }
        wrap?.let { put("wrap", it) }
    }

    companion object {
        val DEFAULT = NoteTableCellStyle()

        fun fromJson(obj: JSONObject?): NoteTableCellStyle {
            if (obj == null) return DEFAULT
            fun bool(key: String): Boolean? = if (obj.has(key) && !obj.isNull(key)) obj.optBoolean(key) else null
            fun str(key: String): String? = if (obj.has(key) && !obj.isNull(key)) obj.optString(key) else null
            return NoteTableCellStyle(
                bold = bool("bold"),
                italic = bool("italic"),
                underline = bool("underline"),
                strikethrough = bool("strikethrough"),
                fontSize = if (obj.has("fontSize") && !obj.isNull("fontSize")) obj.optDouble("fontSize") else null,
                textColorHex = str("textColorHex"),
                fillHex = str("fillHex"),
                hAlign = str("hAlign"),
                vAlign = str("vAlign"),
                textRotation = if (obj.has("textRotation") && !obj.isNull("textRotation")) obj.optInt("textRotation") else null,
                wrap = bool("wrap")
            )
        }

        fun listToJson(styles: List<NoteTableCellStyle>): JSONArray =
            JSONArray().also { array -> styles.forEach { array.put(it.toJson()) } }

        /** 長度不是 `expected` 就回 null（與 Apple 相同：對不上格子的格式寧可不套）。 */
        fun listFromJson(array: JSONArray?, expected: Int): MutableList<NoteTableCellStyle>? {
            if (array == null || array.length() != expected) return null
            return MutableList(array.length()) { fromJson(array.optJSONObject(it)) }
        }
    }
}

/** 一格的底色來源。畫布、縮圖與匯出走同一個判斷（與 Apple `TableCellFillRole` 相同，I4）。 */
sealed class TableCellFillRole {
    data class Own(val hex: String) : TableCellFillRole()
    object Header : TableCellFillRole()
    object BandedRow : TableCellFillRole()
    object BandedColumn : TableCellFillRole()
}

/** 框線樣式（`borderMode`）。未知值與 null 都當 [ALL]（與舊檔一致）。 */
enum class TableBorderMode(val raw: String) {
    ALL("all"), OUTER("outer"), INNER("inner"), HORIZONTAL("horizontal"), NONE("none");

    companion object {
        fun from(raw: String?): TableBorderMode = values().firstOrNull { it.raw == raw } ?: ALL
    }
}

/** 框線線型（`borderStyle`）。未知值與 null 都當實線。 */
enum class TableBorderStyle(val raw: String) {
    SOLID("solid"), DASHED("dashed"), DOTTED("dotted");

    /** 與 Apple `TableBorderStyle.dashPattern(lineWidth:)` 同比例：虛線 4:2、點線 1:1.5（乘線寬）。 */
    fun dashPattern(lineWidth: Float): FloatArray {
        val w = maxOf(0.5f, lineWidth)
        return when (this) {
            SOLID -> FloatArray(0)
            DASHED -> floatArrayOf(w * 4f, w * 2f)
            DOTTED -> floatArrayOf(w, w * 1.5f)
        }
    }

    companion object {
        fun from(raw: String?): TableBorderStyle = values().firstOrNull { it.raw == raw } ?: SOLID
    }
}
