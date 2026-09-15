package com.kairumo.padnote.library

import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession

/**
 * 筆記本層級的平台中繼資料（核心的 `SetNotebookMeta`）。
 *
 * # Android 在此之前完全沒有讀過它
 *
 * Apple 端把「是一本筆記的屬性、但核心沒有對應概念」的東西都放在這裡：
 * 版面樣板、所屬資料夾、討論圖釘、連結卡片、3D 模型、頁面 id、物件堆疊順序。
 * Android 從來沒有讀過 —— 所以 iPad 上排好的圖層、設好的樣板，同步到
 * Android 就像不存在。
 *
 * # 為什麼一定要保留不認得的鍵
 *
 * Android 目前只用得到其中一兩個欄位。**寫回去時如果只寫自己認得的，
 * 其餘全部會被清掉** —— 使用者在 iPad 上的圖釘、連結卡片、3D 模型會在
 * 同步一趟之後整批消失，而且沒有任何錯誤訊息。
 *
 * 所以這裡的做法是：原樣讀進 `JSONObject`，只改自己要改的鍵，再原樣寫回去。
 */
class NotebookMeta private constructor(private val root: JSONObject) {

    companion object {
        private const val KEY_ORDER_BY_PAGE = "objectOrderByPage"
        /** v3.8.0 的舊欄位：整本一份。只讀不寫，見 format-spec §6.2.1。 */
        private const val KEY_LEGACY_ORDER = "objectOrder"
        private const val KEY_COMMENT_PINS = "commentPins"
        private const val KEY_MODELS_3D = "model3DAttachments"

        fun load(session: PadnoteSession?): NotebookMeta {
            val json = runCatching { session?.notebookMeta() }.getOrNull()
            val obj = runCatching { JSONObject(json ?: "{}") }.getOrNull() ?: JSONObject()
            return NotebookMeta(obj)
        }
    }

    /**
     * 某一頁的物件堆疊順序（由後到前）。
     *
     * 沒有逐頁資料時退回 v3.8.0 的舊欄位 —— 與 Apple 端同一條規則。
     */
    fun objectOrder(pageIndex: Int): List<String> {
        root.optJSONObject(KEY_ORDER_BY_PAGE)?.optJSONArray(pageIndex.toString())?.let {
            return it.toStringList()
        }
        return root.optJSONArray(KEY_LEGACY_ORDER)?.toStringList() ?: emptyList()
    }

    /** 寫入某一頁的順序並落盤。**只動那一頁**，其餘頁面與其餘欄位原封不動。 */
    fun setObjectOrder(session: PadnoteSession?, pageIndex: Int, order: List<String>) {
        val map = root.optJSONObject(KEY_ORDER_BY_PAGE) ?: JSONObject()
        map.put(pageIndex.toString(), JSONArray(order))
        root.put(KEY_ORDER_BY_PAGE, map)
        runCatching { session?.setNotebookMeta(root.toString()) }
    }

    /** 這本筆記的討論圖釘。Apple 端把它們放在這裡，核心沒有這個概念。 */
    fun commentPins(): MutableList<com.kairumo.padnote.comment.CommentPin> =
        com.kairumo.padnote.comment.CommentPinCodec.decodeAll(root.optJSONArray(KEY_COMMENT_PINS))

    /** 寫回圖釘並落盤。其餘欄位原封不動 —— 見這個類別開頭的說明。 */
    fun setCommentPins(
        session: PadnoteSession?,
        pins: List<com.kairumo.padnote.comment.CommentPin>
    ) {
        root.put(KEY_COMMENT_PINS, com.kairumo.padnote.comment.CommentPinCodec.encodeAll(pins))
        runCatching { session?.setNotebookMeta(root.toString()) }
    }

    /**
     * 這本筆記的 3D 模型。核心沒有對應的區塊型別，所以 Apple 端把它們
     * 原樣放在中繼資料裡，Android 讀寫的是同一個鍵。
     */
    fun models3D(): MutableList<com.kairumo.padnote.model3d.Model3DObject> =
        com.kairumo.padnote.model3d.Model3DCodec.decodeAll(root.optJSONArray(KEY_MODELS_3D))

    /** 寫回 3D 模型並落盤。其餘欄位原封不動 —— 見這個類別開頭的說明。 */
    fun setModels3D(
        session: PadnoteSession?,
        models: List<com.kairumo.padnote.model3d.Model3DObject>
    ) {
        root.put(KEY_MODELS_3D, com.kairumo.padnote.model3d.Model3DCodec.encodeAll(models))
        runCatching { session?.setNotebookMeta(root.toString()) }
    }

    private fun JSONArray.toStringList(): List<String> =
        (0 until length()).mapNotNull { optString(it).takeIf { s -> s.isNotEmpty() } }
}
