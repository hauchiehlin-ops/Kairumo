package com.kairumo.padnote.shape

import org.json.JSONObject

/**
 * 形狀與連接線的樣式 ⇄ 筆記本中繼資料裡的 JSON。
 *
 * **鍵名與 Apple 的 `ShapeStyleMeta`／`ConnectionStyleMeta` 逐字一致** —— 這份 JSON
 * 會寫進 `.padnote` 同步到另一台裝置，鍵名不同等於兩邊各存各的。
 * 只能加欄位、不能改名；每個欄位都可缺省。
 */
object ShapeStyleMeta {

    fun encode(shape: NoteShape): JSONObject = JSONObject().apply {
        put("kind", shape.kindName)
        put("label", shape.label)
        put("cornerRadius", shape.cornerRadius.toDouble())
        shape.strokeColorHex?.let { put("stroke", it) }
        shape.fillColorHex?.let { put("fill", it) }
        put("lineWidth", shape.lineWidth.toDouble())
        shape.dashStyle?.let { put("dash", it) }
        shape.fontSize?.let { put("fontSize", it.toDouble()) }
        shape.textColorHex?.let { put("textColor", it) }
        shape.isBold?.let { put("bold", it) }
        shape.isItalic?.let { put("italic", it) }
        shape.opacity?.let { put("opacity", it.toDouble()) }
        shape.groupId?.let { put("groupId", it) }
    }

    /** 把樣式套回形狀。位置、大小、旋轉不在這裡 —— 它們走核心的物件變換。 */
    fun apply(json: JSONObject, shape: NoteShape) {
        if (json.has("kind")) shape.kindName = json.optString("kind", shape.kindName)
        if (json.has("label")) shape.label = json.optString("label", shape.label)
        if (json.has("cornerRadius")) shape.cornerRadius = json.optDouble("cornerRadius").toFloat()
        shape.strokeColorHex = if (json.has("stroke")) json.optString("stroke") else null
        shape.fillColorHex = if (json.has("fill")) json.optString("fill") else null
        if (json.has("lineWidth")) shape.lineWidth = json.optDouble("lineWidth").toFloat()
        shape.dashStyle = if (json.has("dash")) json.optString("dash") else null
        shape.fontSize = if (json.has("fontSize")) json.optDouble("fontSize").toFloat() else null
        shape.textColorHex = if (json.has("textColor")) json.optString("textColor") else null
        shape.isBold = if (json.has("bold")) json.optBoolean("bold") else null
        shape.isItalic = if (json.has("italic")) json.optBoolean("italic") else null
        shape.opacity = if (json.has("opacity")) json.optDouble("opacity").toFloat() else null
        // 群組以核心的 Group 節點為準，不從這裡覆蓋。
    }

    fun encode(link: NoteConnection): JSONObject = JSONObject().apply {
        link.fromAnchor?.let { put("fromAnchor", it) }
        link.toAnchor?.let { put("toAnchor", it) }
        link.route?.let { put("route", it) }
        link.startCap?.let { put("startCap", it) }
        link.endCap?.let { put("endCap", it) }
        put("label", link.label)
        link.colorHex?.let { put("color", it) }
        put("lineWidth", link.lineWidth.toDouble())
        link.dashStyle?.let { put("dash", it) }
    }

    fun apply(json: JSONObject, link: NoteConnection) {
        link.fromAnchor = if (json.has("fromAnchor")) json.optString("fromAnchor") else null
        link.toAnchor = if (json.has("toAnchor")) json.optString("toAnchor") else null
        link.route = if (json.has("route")) json.optString("route") else null
        link.startCap = if (json.has("startCap")) json.optString("startCap") else null
        link.endCap = if (json.has("endCap")) json.optString("endCap") else null
        if (json.has("label")) link.label = json.optString("label", link.label)
        link.colorHex = if (json.has("color")) json.optString("color") else null
        if (json.has("lineWidth")) link.lineWidth = json.optDouble("lineWidth").toFloat()
        link.dashStyle = if (json.has("dash")) json.optString("dash") else null
    }
}
