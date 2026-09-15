package com.kairumo.padnote.image

import org.json.JSONArray
import org.json.JSONObject

/**
 * 一張連結卡片。
 *
 * # 欄位名必須與 Apple 的 `NoteLinkAttachment` 完全一致
 *
 * 這份資料跟著筆記本中繼資料（`linkAttachments`）走，而中繼資料是同步的。
 * 欄位名差一個字母，Apple 建的卡片在 Android 上就會缺那一項 ——
 * 而且**反過來會把它清掉**：Android 存回去時沒有那個欄位，下一次同步
 * Apple 那邊就讀不到了。
 *
 * 所以這裡的 key 是照 Swift 的 `Codable` 預設命名抄的，不是自己取的。
 */
data class LinkObject(
    val id: String,
    val pageIndex: Int,
    val urlString: String,
    val title: String,
    val descriptionText: String,
    val siteName: String,
    var x: Float,
    var y: Float,
    var width: Float,
    var height: Float,
    var rotationDegrees: Float = 0f,
    val hasBorder: Boolean = true,
    val cornerRadius: Float = 10f,
    /**
     * 認不得的欄位原樣留著。
     *
     * Apple 帶了我們還沒實作的樣式（邊框顏色、底色…），寫回去時要一起
     * 帶回去 —— 丟掉的話，使用者在 iPad 上調好的樣式會在 Android 開一次
     * 之後**靜靜消失**。
     */
    val unknown: JSONObject = JSONObject()
)

object LinkCodec {

    /** 這幾個是我們認得的，其餘進 `unknown`。 */
    private val KNOWN = setOf(
        "id", "pageIndex", "urlString", "title", "descriptionText", "siteName",
        "x", "y", "width", "height", "rotationDegrees", "hasBorder", "cornerRadius"
    )

    fun decodeAll(array: JSONArray?): MutableList<LinkObject> {
        val out = mutableListOf<LinkObject>()
        val source = array ?: return out
        for (i in 0 until source.length()) {
            val obj = source.optJSONObject(i) ?: continue
            val id = obj.optString("id").takeIf { it.isNotEmpty() } ?: continue
            val unknown = JSONObject()
            for (key in obj.keys()) {
                if (key !in KNOWN) unknown.put(key, obj.get(key))
            }
            out += LinkObject(
                id = id,
                pageIndex = obj.optInt("pageIndex", 0),
                urlString = obj.optString("urlString"),
                title = obj.optString("title"),
                descriptionText = obj.optString("descriptionText"),
                siteName = obj.optString("siteName"),
                x = obj.optDouble("x", 80.0).toFloat(),
                y = obj.optDouble("y", 180.0).toFloat(),
                width = obj.optDouble("width", 280.0).toFloat(),
                height = obj.optDouble("height", 96.0).toFloat(),
                rotationDegrees = obj.optDouble("rotationDegrees", 0.0).toFloat(),
                hasBorder = obj.optBoolean("hasBorder", true),
                cornerRadius = obj.optDouble("cornerRadius", 10.0).toFloat(),
                unknown = unknown
            )
        }
        return out
    }

    fun encodeAll(items: List<LinkObject>): JSONArray {
        val array = JSONArray()
        for (item in items) {
            // 先把不認得的欄位放回去，再寫我們認得的 —— 順序反過來的話，
            // `unknown` 裡萬一有同名的舊值會蓋掉新值。
            val obj = JSONObject()
            for (key in item.unknown.keys()) obj.put(key, item.unknown.get(key))
            obj.put("id", item.id)
            obj.put("pageIndex", item.pageIndex)
            obj.put("urlString", item.urlString)
            obj.put("title", item.title)
            obj.put("descriptionText", item.descriptionText)
            obj.put("siteName", item.siteName)
            obj.put("x", item.x.toDouble())
            obj.put("y", item.y.toDouble())
            obj.put("width", item.width.toDouble())
            obj.put("height", item.height.toDouble())
            obj.put("rotationDegrees", item.rotationDegrees.toDouble())
            obj.put("hasBorder", item.hasBorder)
            obj.put("cornerRadius", item.cornerRadius.toDouble())
            array.put(obj)
        }
        return array
    }
}
