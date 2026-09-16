package com.kairumo.padnote.audio

import org.json.JSONArray
import org.json.JSONObject

/**
 * 頁面上的一張錄音卡片。
 *
 * # 欄位名必須與 Apple 的 `NoteAudioAttachment` 完全一致
 *
 * 這份資料跟著筆記本中繼資料（`audioAttachments`）走，而中繼資料是同步的。
 * 欄位名差一個字母，Apple 建的卡片在 Android 上就會缺那一項 ——
 * 而且**反過來會把它清掉**：Android 存回去時沒有那個欄位，下一次同步
 * Apple 那邊就讀不到了。（與 [com.kairumo.padnote.image.LinkObject] 同一條規則。）
 *
 * # 為什麼不沿用「整本一段錄音」
 *
 * 那個做法沒有座標也沒有頁次，使用者沒辦法把錄音擺在它對應的那一段筆記
 * 旁邊。要做到那件事，錄音必須是一個**有位置的物件**。
 */
data class AudioObject(
    val id: String,
    val pageIndex: Int,
    /** 對應的錄音索引 id。索引沒了仍然保留，播放走 [fileName]。 */
    val recordingId: String,
    /** 音檔檔名（相對於筆記本套件的 `media/audio`）。 */
    val fileName: String,
    var title: String,
    var durationSeconds: Int,
    var x: Float,
    var y: Float,
    var width: Float,
    var height: Float,
    var rotationDegrees: Float = 0f,
    val hasBorder: Boolean = true,
    val cornerRadius: Float = 12f,
    /**
     * 認不得的欄位原樣留著 —— Apple 帶了我們還沒實作的樣式時，
     * 寫回去要一起帶回去，否則使用者調好的樣式會靜靜消失。
     */
    val unknown: JSONObject = JSONObject()
)

object AudioCodec {

    private val KNOWN = setOf(
        "id", "pageIndex", "recordingId", "fileName", "title", "durationSeconds",
        "x", "y", "width", "height", "rotationDegrees", "hasBorder", "cornerRadius"
    )

    fun decodeAll(array: JSONArray?): MutableList<AudioObject> {
        val out = mutableListOf<AudioObject>()
        val source = array ?: return out
        for (i in 0 until source.length()) {
            val obj = source.optJSONObject(i) ?: continue
            val id = obj.optString("id").takeIf { it.isNotEmpty() } ?: continue
            val unknown = JSONObject()
            for (key in obj.keys()) {
                if (key !in KNOWN) unknown.put(key, obj.get(key))
            }
            out += AudioObject(
                id = id,
                pageIndex = obj.optInt("pageIndex", 0),
                recordingId = obj.optString("recordingId"),
                fileName = obj.optString("fileName"),
                title = obj.optString("title"),
                durationSeconds = obj.optInt("durationSeconds", 0),
                x = obj.optDouble("x", 80.0).toFloat(),
                y = obj.optDouble("y", 120.0).toFloat(),
                width = obj.optDouble("width", 260.0).toFloat(),
                height = obj.optDouble("height", 76.0).toFloat(),
                rotationDegrees = obj.optDouble("rotationDegrees", 0.0).toFloat(),
                hasBorder = obj.optBoolean("hasBorder", true),
                cornerRadius = obj.optDouble("cornerRadius", 12.0).toFloat(),
                unknown = unknown
            )
        }
        return out
    }

    fun encodeAll(items: List<AudioObject>): JSONArray {
        val array = JSONArray()
        for (item in items) {
            // 先放不認得的欄位，再寫認得的 —— 順序反過來的話，
            // `unknown` 裡萬一有同名的舊值會蓋掉新值。
            val obj = JSONObject()
            for (key in item.unknown.keys()) obj.put(key, item.unknown.get(key))
            obj.put("id", item.id)
            obj.put("pageIndex", item.pageIndex)
            obj.put("recordingId", item.recordingId)
            obj.put("fileName", item.fileName)
            obj.put("title", item.title)
            obj.put("durationSeconds", item.durationSeconds)
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

    /** `mm:ss`。與 Apple 的 `AudioAttachmentFormat.duration` 同一個格式。 */
    fun duration(seconds: Int): String {
        val safe = maxOf(0, seconds)
        return String.format("%02d:%02d", safe / 60, safe % 60)
    }
}
