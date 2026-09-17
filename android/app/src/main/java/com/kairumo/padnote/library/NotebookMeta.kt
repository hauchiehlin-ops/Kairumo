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

        /**
         * 紙張樣板。**鍵名與 Apple 的 `NotebookMeta.template` 一致。**
         *
         * 存的是 Apple 的 `NoteTemplate.rawValue`：舊的十三種是中文字面值
         * （已經在使用者的檔案裡，動不得），新的是英文 id。換算成紙張 id 的
         * 對照表在核心（`paperIdFromStored`）—— 在這裡再抄一份中文對照，
         * 就是第二份會漂移的東西。
         */
        private const val KEY_TEMPLATE = "template"

        /**
         * 逐頁的紙張樣板 id 與版面配色。鍵名與 Apple 的
         * `NotebookMeta.pageTemplates` / `guidePalette` 一致 —— 這份中繼資料
         * 是同步的，鍵名不一樣等於兩邊各存各的。
         */
        private const val KEY_PAGE_TEMPLATES = "pageTemplates"
        private const val KEY_PALETTE = "guidePalette"

        /**
         * 連結卡片。**鍵名與 Apple 的 `NotebookMeta.linkAttachments` 一致** ——
         * 這份中繼資料是同步的，鍵名不一樣等於兩邊各存各的。
         */
        private const val KEY_LINKS = "linkAttachments"

        /**
         * 頁面上的錄音卡片。鍵名與 Apple 的 `NotebookDocument.audioAttachments`
         * 一致 —— 這份中繼資料是同步的，鍵名不一樣等於兩邊各存各的。
         */
        private const val KEY_AUDIO = "audioAttachments"

        fun load(session: PadnoteSession?): NotebookMeta {
            val json = runCatching { session?.notebookMeta() }.getOrNull()
            val obj = runCatching { JSONObject(json ?: "{}") }.getOrNull() ?: JSONObject()
            return NotebookMeta(obj)
        }
    }

    /**
     * 這本筆記用的是哪一張紙。認不得或沒有時是 `blank`。
     */
    fun paperId(): String =
        uniffi.padnote_core.paperIdFromStored(root.optString(KEY_TEMPLATE, ""))

    /**
     * 某一頁用的紙張。取不到就是整本的那一張 —— 舊筆記沒有逐頁欄位，
     * 而它們每一頁本來就是照整本的樣板畫的。
     */
    fun paperId(pageIndex: Int): String {
        val arr = root.optJSONArray(KEY_PAGE_TEMPLATES)
        val raw = if (arr != null && pageIndex >= 0 && pageIndex < arr.length()) {
            arr.optString(pageIndex, "")
        } else {
            ""
        }
        if (raw.isNotEmpty()) return uniffi.padnote_core.paperIdFromStored(raw)
        return paperId()
    }

    /** 版面配色。認不得或沒有時，核心會回第一組。 */
    fun paletteId(): String = root.optString(KEY_PALETTE, "")

    /** 建立筆記本時記下紙張，重開時版面才回得來。 */
    fun setPaperId(session: PadnoteSession?, paperId: String) {
        root.put(KEY_TEMPLATE, paperId)
        runCatching { session?.setNotebookMeta(root.toString()) }
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
    fun links(): MutableList<com.kairumo.padnote.image.LinkObject> =
        com.kairumo.padnote.image.LinkCodec.decodeAll(root.optJSONArray(KEY_LINKS))

    fun setLinks(
        session: PadnoteSession?,
        items: List<com.kairumo.padnote.image.LinkObject>
    ) {
        root.put(KEY_LINKS, com.kairumo.padnote.image.LinkCodec.encodeAll(items))
        runCatching { session?.setNotebookMeta(root.toString()) }
    }

    /** 這本筆記頁面上的錄音卡片。核心沒有對應的區塊型別，與連結卡片同一條路。 */
    fun audioCards(): MutableList<com.kairumo.padnote.audio.AudioObject> =
        com.kairumo.padnote.audio.AudioCodec.decodeAll(root.optJSONArray(KEY_AUDIO))

    fun setAudioCards(
        session: PadnoteSession?,
        items: List<com.kairumo.padnote.audio.AudioObject>
    ) {
        root.put(KEY_AUDIO, com.kairumo.padnote.audio.AudioCodec.encodeAll(items))
        runCatching { session?.setNotebookMeta(root.toString()) }
    }

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
