package com.kairumo.padnote.text

import org.json.JSONObject

/**
 * 畫布上的文字方塊。
 *
 * 欄位與鍵名對照 `format-spec.md` §6.2，**與 Apple 端的 `NoteTextAttachment`
 * 是同一組**。各寫一組的話，同一個方塊在兩個平台會長得不一樣 ——
 * 而那種不一致只有使用者會發現。
 *
 * `null` 代表「使用者沒設定」，與「使用者設成 0」是兩回事：
 * 前者套平台預設，後者是明確的 0。編碼時 `null` 的欄位**不寫進 JSON**。
 */
data class TextBox(
    val id: String,
    var pageIndex: Int = 0,
    var text: String = "",
    var x: Float = 100f,
    var y: Float = 150f,
    var width: Float = 300f,
    var height: Float = 160f,

    var fontSize: Float = 16f,
    var bold: Boolean = false,
    var italic: Boolean = false,
    var underline: Boolean = false,
    var strikethrough: Boolean = false,
    /** `left` / `center` / `right` / `justified` */
    var alignment: String = "left",
    var textColorHex: String = "#000000",

    /**
     * `#RRGGBB`，或 **`"clear"`（透明）**。
     *
     * `"clear"` 是**哨符不是顏色** —— 它與 `#FFFFFF` 是兩回事，而且不能走
     * 顏色轉換：多數 hex 轉換會丟掉 alpha，透明就變成黑色。Apple 端就是這樣
     * 出過一次 bug。
     */
    var backgroundColorHex: String? = null,
    var hasBorder: Boolean = true,
    var borderColorHex: String? = null,
    var borderWidth: Float? = null,
    var cornerRadius: Float = 8f,

    // 段落
    var lineSpacing: Float? = null,
    var paragraphSpacing: Float? = null,
    var firstLineIndent: Float? = null,
    var paragraphIndent: Float? = null
) {
    val isBackgroundClear: Boolean get() = backgroundColorHex == "clear"
}

/**
 * 外觀的跨平台編碼（`format-spec.md` §6.2）。
 *
 * 核心的 `SetBlockAppearance` 帶的就是這段 JSON，它不解讀內容 ——
 * 鍵名由格式規格定義，兩個平台共用同一組。
 */
object TextBoxAppearance {

    fun encode(box: TextBox): String {
        val json = JSONObject()
        json.put("fontSize", box.fontSize.toDouble())
        json.put("bold", box.bold)
        json.put("italic", box.italic)
        json.put("underline", box.underline)
        json.put("strikethrough", box.strikethrough)
        json.put("alignment", box.alignment)
        json.put("textColorHex", box.textColorHex)
        json.put("hasBorder", box.hasBorder)
        json.put("cornerRadius", box.cornerRadius.toDouble())
        json.put("width", box.width.toDouble())
        json.put("height", box.height.toDouble())

        // null 的欄位不寫進去 —— 接收端才分得出「沒設定」與「設成 0」。
        box.backgroundColorHex?.let { json.put("backgroundColorHex", it) }
        box.borderColorHex?.let { json.put("borderColorHex", it) }
        box.borderWidth?.let { json.put("borderWidth", it.toDouble()) }
        box.lineSpacing?.let { json.put("lineSpacing", it.toDouble()) }
        box.paragraphSpacing?.let { json.put("paragraphSpacing", it.toDouble()) }
        box.firstLineIndent?.let { json.put("firstLineIndent", it.toDouble()) }
        box.paragraphIndent?.let { json.put("paragraphIndent", it.toDouble()) }
        return json.toString()
    }

    /**
     * 把 JSON 套回文字方塊。認不得的鍵一律忽略。
     *
     * 忽略而不是報錯：另一個平台可能帶了我們還沒實作的欄位，那時該做的是
     * 保留其餘設定，不是整塊樣式都不套。
     */
    fun apply(json: String, box: TextBox) {
        val obj = runCatching { JSONObject(json) }.getOrNull() ?: return

        if (obj.has("fontSize")) box.fontSize = obj.getDouble("fontSize").toFloat()
        if (obj.has("bold")) box.bold = obj.getBoolean("bold")
        if (obj.has("italic")) box.italic = obj.getBoolean("italic")
        if (obj.has("underline")) box.underline = obj.getBoolean("underline")
        if (obj.has("strikethrough")) box.strikethrough = obj.getBoolean("strikethrough")
        if (obj.has("alignment")) box.alignment = obj.getString("alignment")
        if (obj.has("textColorHex")) box.textColorHex = obj.getString("textColorHex")
        if (obj.has("backgroundColorHex")) box.backgroundColorHex = obj.getString("backgroundColorHex")
        if (obj.has("hasBorder")) box.hasBorder = obj.getBoolean("hasBorder")
        if (obj.has("borderColorHex")) box.borderColorHex = obj.getString("borderColorHex")
        if (obj.has("borderWidth")) box.borderWidth = obj.getDouble("borderWidth").toFloat()
        if (obj.has("cornerRadius")) box.cornerRadius = obj.getDouble("cornerRadius").toFloat()
        if (obj.has("width")) box.width = obj.getDouble("width").toFloat()
        if (obj.has("height")) box.height = obj.getDouble("height").toFloat()
        if (obj.has("lineSpacing")) box.lineSpacing = obj.getDouble("lineSpacing").toFloat()
        if (obj.has("paragraphSpacing")) box.paragraphSpacing = obj.getDouble("paragraphSpacing").toFloat()
        if (obj.has("firstLineIndent")) box.firstLineIndent = obj.getDouble("firstLineIndent").toFloat()
        if (obj.has("paragraphIndent")) box.paragraphIndent = obj.getDouble("paragraphIndent").toFloat()
    }
}
