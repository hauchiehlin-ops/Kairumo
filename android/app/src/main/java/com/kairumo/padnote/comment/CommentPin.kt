package com.kairumo.padnote.comment

import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * 討論串的一則訊息。欄位與 Apple 端的 `NoteCommentMessage` 一對一。
 */
data class CommentMessage(
    val id: String,
    val authorId: String,
    val authorName: String,
    val authorColor: String,
    var text: String,
    val createdAt: Date
)

/**
 * 畫布上的討論圖釘。欄位與 Apple 端的 `NoteCommentPin` 一對一。
 *
 * 圖釘存在**筆記本中繼資料**裡（核心沒有這個概念），所以它跨得過平台 ——
 * Android 在此之前讀不到，iPad 上標的討論同步過來就像不存在。
 */
data class CommentPin(
    val id: String,
    var pageIndex: Int,
    var x: Float,
    var y: Float,
    val authorId: String,
    val authorName: String,
    val authorColor: String,
    val createdAt: Date,
    var isResolved: Boolean,
    val messages: MutableList<CommentMessage>
)

/**
 * 圖釘的 JSON 編解碼。
 *
 * **日期用 ISO 8601（UTC）**，與 Apple 端的 `dateEncodingStrategy = .iso8601`
 * 對齊。用時間戳數字的話，Apple 解不開；用本地時區的字串，跨時區會差幾小時。
 */
object CommentPinCodec {

    private fun isoFormat(): SimpleDateFormat =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

    fun decodeAll(array: JSONArray?): MutableList<CommentPin> {
        val result = mutableListOf<CommentPin>()
        if (array == null) return result
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            decode(obj)?.let { result.add(it) }
        }
        return result
    }

    private fun decode(obj: JSONObject): CommentPin? {
        val id = obj.optString("id").takeIf { it.isNotEmpty() } ?: return null
        val messages = mutableListOf<CommentMessage>()
        obj.optJSONArray("messages")?.let { arr ->
            for (i in 0 until arr.length()) {
                val m = arr.optJSONObject(i) ?: continue
                messages.add(
                    CommentMessage(
                        id = m.optString("id"),
                        authorId = m.optString("authorId"),
                        authorName = m.optString("authorName"),
                        authorColor = m.optString("authorColor", "#007AFF"),
                        text = m.optString("text"),
                        createdAt = parseDate(m.optString("createdAt"))
                    )
                )
            }
        }
        return CommentPin(
            id = id,
            pageIndex = obj.optInt("pageIndex", 0),
            x = obj.optDouble("x", 100.0).toFloat(),
            y = obj.optDouble("y", 100.0).toFloat(),
            authorId = obj.optString("authorId"),
            authorName = obj.optString("authorName"),
            authorColor = obj.optString("authorColor", "#007AFF"),
            createdAt = parseDate(obj.optString("createdAt")),
            isResolved = obj.optBoolean("isResolved", false),
            messages = messages
        )
    }

    fun encodeAll(pins: List<CommentPin>): JSONArray {
        val array = JSONArray()
        val fmt = isoFormat()
        for (pin in pins) {
            val messages = JSONArray()
            for (m in pin.messages) {
                messages.put(
                    JSONObject()
                        .put("id", m.id)
                        .put("authorId", m.authorId)
                        .put("authorName", m.authorName)
                        .put("authorColor", m.authorColor)
                        .put("text", m.text)
                        .put("createdAt", fmt.format(m.createdAt))
                )
            }
            array.put(
                JSONObject()
                    .put("id", pin.id)
                    .put("pageIndex", pin.pageIndex)
                    .put("x", pin.x.toDouble())
                    .put("y", pin.y.toDouble())
                    .put("authorId", pin.authorId)
                    .put("authorName", pin.authorName)
                    .put("authorColor", pin.authorColor)
                    .put("createdAt", fmt.format(pin.createdAt))
                    .put("isResolved", pin.isResolved)
                    .put("messages", messages)
            )
        }
        return array
    }

    /**
     * 解 ISO 8601。解不開時回**現在**而不是 1970 ——
     * 一串 1970 的討論排序會全部跑到最前面，比時間稍微不準更糟。
     */
    private fun parseDate(raw: String): Date {
        if (raw.isEmpty()) return Date()
        // Apple 的 .iso8601 可能帶或不帶毫秒，兩種都要接得住。
        for (pattern in listOf("yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")) {
            runCatching {
                val f = SimpleDateFormat(pattern, Locale.US).apply {
                    timeZone = TimeZone.getTimeZone("UTC")
                }
                return f.parse(raw) ?: Date()
            }
        }
        return Date()
    }
}
