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
class NotebookMeta private constructor(private var root: JSONObject) {

    /**
     * 載入當下的樣子。落盤時拿它判斷「這個實例動過哪些鍵」。
     *
     * 編輯器裡同時有好幾個實例（編輯器本體、連續頁面模式的每一頁、形狀儲存……），
     * 各自把**整份** `root` 寫回去的話，後寫的會把先寫的蓋掉 —— 一個實例改了
     * 物件順序，另一個實例（載入時還沒有那個鍵的）下一次落盤就把它洗掉，
     * 而且沒有任何錯誤。所以落盤時只寫**自己動過的鍵**，其餘的以磁碟上最新的為準。
     */
    private var snapshot: JSONObject = JSONObject(root.toString())

    private fun flush(session: PadnoteSession?) {
        if (session == null) return
        runCatching {
            val latest = runCatching { JSONObject(session.notebookMeta() ?: "{}") }
                .getOrNull() ?: JSONObject()
            val keys = HashSet<String>().apply {
                root.keys().forEach { add(it) }
                snapshot.keys().forEach { add(it) }
            }
            for (key in keys) {
                val mine = root.opt(key)
                val before = snapshot.opt(key)
                val changed = when {
                    mine == null && before == null -> false
                    mine == null || before == null -> true
                    else -> mine.toString() != before.toString()
                }
                if (!changed) continue
                if (mine == null) latest.remove(key) else latest.put(key, mine)
            }
            session.setNotebookMeta(latest.toString())
            // 之後的讀取要看得到別的實例剛寫的東西。
            root = latest
            snapshot = JSONObject(latest.toString())
        }
    }

    companion object {
        const val KEY_ORDER_BY_PAGE = "objectOrderByPage"
        const val KEY_UNDER_INK_BY_PAGE = "underInkObjectIdsByPage"
        /** 明確放到筆跡上方的物件（預設在下方的型別被搬上來）。與 Apple `NotebookMeta.overInkObjectIdsByPage` 同一個鍵。 */
        const val KEY_OVER_INK_BY_PAGE = "overInkObjectIdsByPage"
        /** 鎖定在畫布上的物件（`{"頁次": [id]}`）。與 Apple `NotebookMeta.lockedObjectIdsByPage` 同一個鍵。 */
        const val KEY_LOCKED_BY_PAGE = "lockedObjectIdsByPage"
        /** 「範例」標記（與 Apple `NotebookMeta.isSample` 同一個鍵）。沒有這個鍵 = 沒設定過。 */
        const val KEY_IS_SAMPLE = "isSample"
        /** v3.8.0 的舊欄位：整本一份。只讀不寫，見 format-spec §6.2.1。 */
        private const val KEY_LEGACY_ORDER = "objectOrder"
        private const val KEY_COMMENT_PINS = "commentPins"
        /**
         * Apple 端寫的旗標：清單裡的物件另外有逐物件的區塊，匯入時以區塊為準。
         * Android 改了清單就要清掉它，否則 Apple 會把 Android 新增的物件當成已被刪除而忽略。
         */
        private const val KEY_OBJECT_ENVELOPES = "objectEnvelopes"
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
         * 頁面規格（S-84）。**兩端同一個鍵**，而且它進的是同步的中繼資料 ——
         * 同一本筆記在兩台裝置上的頁面尺寸不一樣的話，分頁位置、可列印範圍
         * 與匯出的 PDF 全部會分家。
         */
        private const val KEY_PAGE_FORMAT = "pageFormat"

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

        /**
         * 手寫與文字動態流式錨定 (Fluid Sticky Annotations)。
         * 鍵名與 Apple 的 `NotebookMeta.stickyAnchors` 一致。
         */
        private const val KEY_STICKY_ANCHORS = "stickyAnchors"

        /**
         * 遮蔽膠帶（Masking Tape）。
         * 鍵名與 Apple 的 `NotebookMeta.tapeAttachments` 一致。
         */
        private const val KEY_TAPES = "tapeAttachments"

        /**
         * 形狀與連接線的樣式，以物件 id 為鍵。**鍵名與 Apple 的
         * `NotebookMeta.shapeStyles`／`connectionStyles` 一致。**
         *
         * 核心的形狀物件只有種類、外框、圓角與文字，而且建立之後沒有「修改」的 API；
         * 顏色、粗細、虛實、字級、連接線的連接點與端點樣式核心完全沒有欄位。
         * 整包放進這份同步的中繼資料，兩個平台讀寫同一組鍵。
         */
        private const val KEY_SHAPE_STYLES = "shapeStyles"
        private const val KEY_CONNECTION_STYLES = "connectionStyles"

        /** 手寫辨識文字（`{"頁次": "文字"}`）。與 Apple `NotebookMeta.recognizedText` 同一個鍵。 */
        private const val KEY_RECOGNIZED_TEXT = "recognizedText"

        /** 每個項目帶 `pageIndex` 的物件清單 —— 頁面結構變動時要跟著換頁碼（見 [remapPageIndexes]）。 */
        private val PAGE_INDEXED_LISTS = listOf(
            KEY_LINKS, KEY_AUDIO, KEY_STICKY_ANCHORS, KEY_TAPES, KEY_COMMENT_PINS, KEY_MODELS_3D
        )

        /** 頁面物件清單的鍵（協同的 `link`、`model3d`…對應到這裡）。 */
        val PAYLOAD_KEYS: Map<String, String> = linkedMapOf(
            "link" to KEY_LINKS, "model3d" to KEY_MODELS_3D, "audio" to KEY_AUDIO,
            "pin" to KEY_COMMENT_PINS, "tape" to KEY_TAPES, "sticky" to KEY_STICKY_ANCHORS
        )
        private val OBJECT_LIST_KEYS = PAYLOAD_KEYS.values.toSet()

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

    /** 使用者設定的「範例」標記；沒設定過回 null（內建範例預設是，見 [SampleFork.isSample]）。 */
    fun isSample(): Boolean? = if (root.has(KEY_IS_SAMPLE)) root.optBoolean(KEY_IS_SAMPLE) else null

    fun setSample(session: PadnoteSession?, isSample: Boolean) {
        root.put(KEY_IS_SAMPLE, isSample)
        flush(session)
    }

    /** 版面配色。認不得或沒有時，核心會回第一組。 */
    fun paletteId(): String = root.optString(KEY_PALETTE, "")

    /** 頁面規格 id（核心 `pageFormats()`）。空字串是預設的 A4 直式。 */
    fun pageFormatId(): String = root.optString(KEY_PAGE_FORMAT, "")

    fun setPageFormatId(session: PadnoteSession?, formatId: String) {
        root.put(KEY_PAGE_FORMAT, formatId)
        flush(session)
    }

    /** 建立筆記本時記下紙張，重開時版面才回得來。 */
    fun setPaperId(session: PadnoteSession?, paperId: String) {
        root.put(KEY_TEMPLATE, paperId)
        flush(session)
    }

    /**
     * 版面配色（S-93）。整本一個調子，與 Apple 的 `guidePaletteId` 同一個欄位。
     *
     * 這份中繼資料會跟著同步走，所以鍵名不能自己取一個。
     */
    fun setPaletteId(session: PadnoteSession?, paletteId: String) {
        root.put(KEY_PALETTE, paletteId)
        flush(session)
    }

    /** 插入某一頁的樣板（S-93）。 */
    fun insertPageTemplate(session: PadnoteSession?, atIndex: Int, paperId: String, totalPages: Int) {
        insertPageTemplateInMemory(atIndex, paperId, totalPages)
        flush(session)
    }

    /**
     * 把第 `from` 頁搬到第 `to` 頁之後，逐頁的資料跟著搬。
     *
     * # 為什麼一定要有這一支
     *
     * `session.movePage()` 搬的是**核心裡的頁面順序**，動不到平台這一層
     * 按頁碼存的東西 —— 紙張樣板與物件堆疊順序都是用頁碼當鍵的。
     * 少了它，症狀是「我搬了一頁，它的版面留在原地」（`STATE.md` 已列）。
     *
     * # 為什麼用核心算新頁碼，而不是自己 `removeAt` + `add`
     *
     * 往後搬與往前搬的區間不對稱，自己寫很容易只對其中一個方向。
     * `pageIndexAfterMove` 是兩個平台共用的那一份規則 ——
     * 這裡逐頁問它「你會落在哪」，就不可能與 Apple 端分岔。
     */
    fun movePageData(session: PadnoteSession?, from: Int, to: Int, totalPages: Int) {
        if (from == to || totalPages <= 1) return
        if (!uniffi.padnote_core.pageMoveIsValid(
                totalPages.toUInt(), from.toUInt(), to.toUInt()
            )
        ) {
            return
        }

        // 紙張樣板
        val defaultPaper = paperId()
        val arr = root.optJSONArray(KEY_PAGE_TEMPLATES)
        val current = MutableList(totalPages) { i ->
            if (arr != null && i < arr.length()) arr.optString(i, defaultPaper) else defaultPaper
        }
        val movedTemplates = arrayOfNulls<String>(totalPages)
        for (i in 0 until totalPages) {
            val dest = uniffi.padnote_core.pageIndexAfterMove(
                i.toUInt(), from.toUInt(), to.toUInt()
            ).toInt()
            if (dest in 0 until totalPages) movedTemplates[dest] = current[i]
        }
        root.put(KEY_PAGE_TEMPLATES, JSONArray(movedTemplates.map { it ?: defaultPaper }))

        // 其餘以頁碼為鍵的資料（堆疊順序、筆跡下方、鎖定、辨識文字）與帶頁碼的物件清單。
        remapPageIndexes { index ->
            if (index >= totalPages) index
            else uniffi.padnote_core.pageIndexAfterMove(index.toUInt(), from.toUInt(), to.toUInt()).toInt()
        }

        flush(session)
    }

    /**
     * 在 `fromIndex` 插入一頁之前：以頁碼為鍵的物件堆疊順序與筆跡下方名單，`fromIndex` 以後的頁都往後挪一格。
     * 紙張樣板由 [insertPageTemplate] 自己挪。不挪的話，插入一頁之後，後面每一頁的圖層設定都錯位一頁。
     */
    fun shiftPageKeyedData(session: PadnoteSession?, fromIndex: Int, totalPagesBefore: Int, by: Int = 1) {
        remapPageIndexes { index -> if (index in fromIndex until totalPagesBefore) index + by else index }
        flush(session)
    }

    /**
     * 整份匯入的 PDF 頁面：每一張鎖定在畫布上、放在那一頁堆疊的最底下，最後只落盤一次。
     *
     * **鎖定**：PDF 頁面是被標註的底稿。不鎖的話，打字模式下點頁面任何一處都會選到這張
     * 整頁的圖。圖層不必另外設定：依核心規則，圖片本來就在筆跡下方。
     */
    fun placePdfPages(session: PadnoteSession?, placed: List<Pair<Int, String>>) {
        if (placed.isEmpty()) return
        val locked = root.optJSONObject(KEY_LOCKED_BY_PAGE) ?: JSONObject()
        val orders = root.optJSONObject(KEY_ORDER_BY_PAGE) ?: JSONObject()
        for ((pageIndex, id) in placed) {
            val key = pageIndex.toString()
            val current = locked.optJSONArray(key)?.toStringList().orEmpty().map { it.lowercase() }.toSortedSet()
            current += id.lowercase()
            locked.put(key, JSONArray(current.toList()))
            val order = orders.optJSONArray(key)?.toStringList().orEmpty().filter { it != id }
            orders.put(key, JSONArray(listOf(id) + order))
        }
        root.put(KEY_LOCKED_BY_PAGE, locked)
        root.put(KEY_ORDER_BY_PAGE, orders)
        flush(session)
    }

    /**
     * 以頁碼記位置的所有東西照 `transform` 換頁碼；回 `null` 的那一頁整個丟掉（刪除頁）。
     *
     * 兩種形狀：以頁碼為鍵的字典（堆疊順序、筆跡下方、鎖定、辨識文字），以及每個項目帶
     * `pageIndex` 的物件清單（連結卡片、錄音卡片、膠帶、錨定、圖釘、3D 模型）。
     * 原本只挪了前兩個字典：搬頁、插頁、刪頁之後，清單裡的物件留在原本的頁碼上 ——
     * 使用者看到的是「筆跡搬過去了，卡片、膠帶留在原地」，刪掉的頁上的卡片跑到下一頁。
     */
    /** `internal`：單元測試直接驗它（主機上的 JVM 載不到核心，`movePageData` 要問核心頁碼規則）。 */
    internal fun remapPageIndexes(transform: (Int) -> Int?) {
        for (key in listOf(KEY_ORDER_BY_PAGE, KEY_UNDER_INK_BY_PAGE, KEY_OVER_INK_BY_PAGE, KEY_LOCKED_BY_PAGE, KEY_RECOGNIZED_TEXT)) {
            val map = root.optJSONObject(key) ?: continue
            val shifted = JSONObject()
            val keys = map.keys()
            while (keys.hasNext()) {
                val k = keys.next()
                val index = k.toIntOrNull()
                if (index == null) { shifted.put(k, map.get(k)); continue }
                transform(index)?.let { shifted.put(it.toString(), map.get(k)) }
            }
            root.put(key, shifted)
        }
        var listsChanged = false
        for (key in PAGE_INDEXED_LISTS) {
            val arr = root.optJSONArray(key) ?: continue
            val out = JSONArray()
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i)
                if (item == null || !item.has("pageIndex")) { out.put(arr.opt(i)); continue }
                val before = item.optInt("pageIndex", 0)
                val after = transform(before)
                if (after != before) listsChanged = true
                if (after == null) continue
                out.put(JSONObject(item.toString()).put("pageIndex", after))
            }
            root.put(key, out)
        }
        // 清單改了：Apple 端的「以逐物件區塊為準」旗標要清掉，不然它把清單的新內容當成舊的（見 KEY_OBJECT_ENVELOPES）。
        if (listsChanged) root.remove(KEY_OBJECT_ENVELOPES)
    }

    /**
     * 另一本筆記的第 `sourcePage` 頁剛被複製（或搬）進這本、成了第 `targetPage` 頁
     * （核心的 `transferPagesMapped`）：把那一頁存在**中繼資料**裡的東西跟著帶過來。
     *
     * 核心只搬得動它自己的東西（區塊、筆畫、形狀、連接線）。紙張、連結卡片、錄音卡片、
     * 膠帶、圖釘、3D 模型、錨定、堆疊順序、筆跡下方名單、鎖定、形狀樣式、辨識文字住在
     * 這份中繼資料裡 —— 不帶的話，搬過去的頁只剩筆跡與文字，其餘整組不見
     * （與 Apple `NotebookStore.transferPages` 帶的是同一批）。
     *
     * `idMap`：來源物件 id → 這本的物件 id（核心回傳）。清單裡的項目在這裡換新 id，
     * 也併進同一張對照表，堆疊順序與錨定才指得到新的那一份。
     */
    fun receivePage(
        session: PadnoteSession?,
        source: NotebookMeta,
        sourcePage: Int,
        targetPage: Int,
        idMap: Map<String, String>
    ) {
        val ids = HashMap<String, String>()
        idMap.forEach { (k, v) -> ids[k.lowercase()] = v }

        // 紙張：新頁在最後，前面有 targetPage 頁。
        insertPageTemplateInMemory(targetPage, source.paperId(sourcePage), targetPage)

        // 帶 pageIndex 的清單：換新 id、換頁碼。錨定最後做（要用到前面換出來的 id）。
        var listsChanged = false
        for (key in PAGE_INDEXED_LISTS) {
            if (key == KEY_STICKY_ANCHORS) continue
            val from = source.root.optJSONArray(key) ?: continue
            val into = root.optJSONArray(key) ?: JSONArray()
            for (i in 0 until from.length()) {
                val item = from.optJSONObject(i) ?: continue
                if (item.optInt("pageIndex", -1) != sourcePage) continue
                val copy = JSONObject(item.toString()).put("pageIndex", targetPage)
                item.optString("id").takeIf { it.isNotEmpty() }?.let { old ->
                    val fresh = java.util.UUID.randomUUID().toString()
                    ids[old.lowercase()] = fresh
                    copy.put("id", fresh)
                }
                into.put(copy)
                listsChanged = true
            }
            root.put(key, into)
        }
        source.root.optJSONArray(KEY_STICKY_ANCHORS)?.let { from ->
            val into = root.optJSONArray(KEY_STICKY_ANCHORS) ?: JSONArray()
            for (i in 0 until from.length()) {
                val item = from.optJSONObject(i) ?: continue
                if (item.optInt("pageIndex", -1) != sourcePage) continue
                // 錨在沒帶過來的東西上就不帶 —— 指向不存在物件的錨定只會讓筆跡莫名其妙跟著別人動。
                val target = ids[item.optString("targetId").lowercase()] ?: continue
                into.put(
                    JSONObject(item.toString())
                        .put("id", java.util.UUID.randomUUID().toString())
                        .put("pageIndex", targetPage)
                        .put("targetId", target)
                )
                listsChanged = true
            }
            root.put(KEY_STICKY_ANCHORS, into)
        }

        // 以頁碼為鍵、內容是物件 id 的清單：換成這本的 id，沒帶過來的丟掉。
        for (key in listOf(KEY_ORDER_BY_PAGE, KEY_UNDER_INK_BY_PAGE, KEY_OVER_INK_BY_PAGE, KEY_LOCKED_BY_PAGE)) {
            val list = source.root.optJSONObject(key)?.optJSONArray(sourcePage.toString()) ?: continue
            val mapped = list.toStringList().mapNotNull { ids[it.lowercase()] }
            if (mapped.isEmpty()) continue
            val map = root.optJSONObject(key) ?: JSONObject()
            map.put(targetPage.toString(), JSONArray(if (key == KEY_ORDER_BY_PAGE) mapped else mapped.sorted()))
            root.put(key, map)
        }
        source.root.optJSONObject(KEY_RECOGNIZED_TEXT)?.optString(sourcePage.toString())
            ?.takeIf { it.isNotEmpty() }
            ?.let { text ->
                val map = root.optJSONObject(KEY_RECOGNIZED_TEXT) ?: JSONObject()
                root.put(KEY_RECOGNIZED_TEXT, map.put(targetPage.toString(), text))
            }

        // 形狀與連接線的樣式（以物件 id 為鍵）。
        for (key in listOf(KEY_SHAPE_STYLES, KEY_CONNECTION_STYLES)) {
            val upserts = source.styleMap(key).mapNotNull { (old, style) -> ids[old]?.let { it to style } }
            if (upserts.isEmpty()) continue
            val obj = root.optJSONObject(key) ?: JSONObject()
            upserts.forEach { (k, v) -> obj.put(k, v) }
            root.put(key, obj)
        }

        if (listsChanged) root.remove(KEY_OBJECT_ENVELOPES)
        flush(session)
    }

    private fun insertPageTemplateInMemory(atIndex: Int, paperId: String, totalPages: Int) {
        val arr = root.optJSONArray(KEY_PAGE_TEMPLATES)
        val defaultPaper = paperId()
        val current = MutableList(totalPages) { i ->
            if (arr != null && i < arr.length()) arr.optString(i, defaultPaper) else defaultPaper
        }
        current.add(atIndex.coerceIn(0, current.size), paperId)
        root.put(KEY_PAGE_TEMPLATES, JSONArray(current))
    }

    /** 設定某一頁的紙張（協同：別人換了那一頁的紙）。 */
    fun setPagePaperId(session: PadnoteSession?, pageIndex: Int, paperId: String, totalPages: Int) {
        val arr = root.optJSONArray(KEY_PAGE_TEMPLATES)
        val defaultPaper = paperId()
        val current = MutableList(maxOf(totalPages, pageIndex + 1)) { i ->
            if (arr != null && i < arr.length()) arr.optString(i, defaultPaper) else defaultPaper
        }
        if (current[pageIndex] == paperId && arr != null && pageIndex < arr.length()) return
        current[pageIndex] = paperId
        root.put(KEY_PAGE_TEMPLATES, JSONArray(current))
        flush(session)
    }

    /**
     * 協同用的原樣讀寫（設計 §8.2）。線上格式就是套件格式，所以連結卡片、圖釘這些清單
     * 以 JSON 原樣進出 —— 經過型別化的編解碼會丟掉這一版不認得的欄位。
     */
    fun raw(key: String): Any? = root.opt(key)

    /** 原樣寫回一個鍵（`null` = 移除）。改的是物件清單時一併清掉 `objectEnvelopes`（理由見那個鍵的說明）。 */
    fun setRaw(session: PadnoteSession?, key: String, value: Any?) {
        if (key in OBJECT_LIST_KEYS) root.remove(KEY_OBJECT_ENVELOPES)
        if (value == null) root.remove(key) else root.put(key, value)
        flush(session)
    }

    /** 重新讀一次核心裡的中繼資料（別的實例或協同剛寫過）。 */
    fun refresh(session: PadnoteSession?) {
        val latest = runCatching { JSONObject(session?.notebookMeta() ?: return) }.getOrNull() ?: return
        root = latest
        snapshot = JSONObject(latest.toString())
    }

    /** 移除某一頁的樣板。 */
    fun removePageTemplate(session: PadnoteSession?, atIndex: Int, totalPages: Int) {
        val currentTemplates = mutableListOf<String>()
        val arr = root.optJSONArray(KEY_PAGE_TEMPLATES)
        val defaultPaper = paperId()
        for (i in 0 until totalPages) {
            val p = if (arr != null && i < arr.length()) arr.optString(i, defaultPaper) else defaultPaper
            currentTemplates.add(p)
        }
        if (atIndex in currentTemplates.indices) {
            currentTemplates.removeAt(atIndex)
        }
        root.put(KEY_PAGE_TEMPLATES, JSONArray(currentTemplates))
        // 被刪的那一頁上的東西一起丟掉，後面每一頁往前補一格。
        remapPageIndexes { index -> when { index == atIndex -> null; index > atIndex -> index - 1; else -> index } }
        flush(session)
    }

    /**
     * 某一頁**明確**放到手寫筆跡下方的物件 ID（使用者搬過，或範例筆記的背景卡片）。
     *
     * 沒列在這裡的物件照型別的預設（核心 `padnote-core::ffi_layering`）：插入的素材在筆跡
     * 下方，文字與圖釘在上方。實際在哪一層一律問 [underInkObjectIds]（帶種類的那個）。
     */
    fun explicitUnderInkObjectIds(pageIndex: Int): Set<String> = pageIdSet(KEY_UNDER_INK_BY_PAGE, pageIndex)

    /** 某一頁**明確**放到筆跡上方的物件 ID（預設在下方、被使用者搬上來的）。 */
    fun explicitOverInkObjectIds(pageIndex: Int): Set<String> = pageIdSet(KEY_OVER_INK_BY_PAGE, pageIndex)

    private fun pageIdSet(key: String, pageIndex: Int): Set<String> {
        val map = root.optJSONObject(key) ?: return emptySet()
        val arr = map.optJSONArray(pageIndex.toString()) ?: return emptySet()
        return arr.toStringList().toSet()
    }

    /** 這一頁**實際**在筆跡下方的物件。[kinds] 是這一頁上每個物件的種類。 */
    fun underInkObjectIds(pageIndex: Int, kinds: Map<String, com.kairumo.padnote.canvas.ObjectStacking.Kind>): Set<String> =
        com.kairumo.padnote.canvas.ObjectStacking.belowInk(
            kinds, explicitUnderInkObjectIds(pageIndex), explicitOverInkObjectIds(pageIndex))

    /**
     * 把物件搬到筆跡上方或下方並落盤。兩份清單怎麼寫由核心決定（`moveObjectsToInkPlane`）：
     * 放到下方一定寫進舊版也認得的 `underInkObjectIdsByPage`。
     */
    fun moveObjectsToInkPlane(
        session: PadnoteSession?,
        pageIndex: Int,
        moving: Map<String, com.kairumo.padnote.canvas.ObjectStacking.Kind>,
        plane: uniffi.padnote_core.FfiInkPlane
    ) {
        if (moving.isEmpty()) return
        val lists = uniffi.padnote_core.moveObjectsToInkPlane(
            com.kairumo.padnote.canvas.ObjectStacking.layerObjects(moving), plane,
            explicitUnderInkObjectIds(pageIndex).toList(), explicitOverInkObjectIds(pageIndex).toList())
        putPageIds(KEY_UNDER_INK_BY_PAGE, pageIndex, lists.under)
        putPageIds(KEY_OVER_INK_BY_PAGE, pageIndex, lists.over)
        flush(session)
    }

    /** 寫入某一頁明確放在筆跡上方的物件清單並落盤（搬頁、複製頁時跟著搬）。 */
    fun setOverInkObjectIds(session: PadnoteSession?, pageIndex: Int, ids: Set<String>) {
        putPageIds(KEY_OVER_INK_BY_PAGE, pageIndex, ids.sorted())
        flush(session)
    }

    private fun putPageIds(key: String, pageIndex: Int, ids: List<String>) {
        val map = root.optJSONObject(key) ?: JSONObject()
        if (ids.isEmpty()) map.remove(pageIndex.toString()) else map.put(pageIndex.toString(), JSONArray(ids))
        if (map.length() == 0) root.remove(key) else root.put(key, map)
    }

    /**
     * 所有頁面鎖定在畫布上的物件（不分頁）。物件 id 全域唯一，不分頁查的話
     * 頁面搬移、插頁之後頁次鍵對不上也不會鎖錯或漏鎖。見 canvas/ObjectLock.kt。
     */
    fun lockedObjectIds(): Set<String> {
        val map = root.optJSONObject(KEY_LOCKED_BY_PAGE) ?: return emptySet()
        val out = HashSet<String>()
        val keys = map.keys()
        while (keys.hasNext()) out += map.optJSONArray(keys.next())?.toStringList().orEmpty().map { it.lowercase() }
        return out
    }

    /** 鎖定／解除鎖定一個物件並落盤。解除時每一頁都拿掉（它記在哪個頁次鍵底下不一定是現在這一頁）。 */
    fun setObjectLocked(session: PadnoteSession?, pageIndex: Int, id: String, locked: Boolean) {
        val map = root.optJSONObject(KEY_LOCKED_BY_PAGE) ?: JSONObject()
        val lowerId = id.lowercase()
        if (locked) {
            val current = map.optJSONArray(pageIndex.toString())?.toStringList().orEmpty().map { it.lowercase() }.toSortedSet()
            current += lowerId
            map.put(pageIndex.toString(), JSONArray(current.toList()))
        } else {
            for (key in map.keys().asSequence().toList()) {
                val remaining = map.optJSONArray(key)?.toStringList().orEmpty().filter { it.lowercase() != lowerId }.sorted()
                if (remaining.isEmpty()) map.remove(key) else map.put(key, JSONArray(remaining))
            }
        }
        if (map.length() == 0) root.remove(KEY_LOCKED_BY_PAGE) else root.put(KEY_LOCKED_BY_PAGE, map)
        flush(session)
    }

    /** 寫入某一頁位於筆跡下方的物件清單並落盤。 */
    fun setUnderInkObjectIds(session: PadnoteSession?, pageIndex: Int, ids: Set<String>) {
        val map = root.optJSONObject(KEY_UNDER_INK_BY_PAGE) ?: JSONObject()
        if (ids.isEmpty()) {
            map.remove(pageIndex.toString())
        } else {
            map.put(pageIndex.toString(), JSONArray(ids.toList()))
        }
        root.put(KEY_UNDER_INK_BY_PAGE, map)
        flush(session)
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
        flush(session)
    }

    /** 這本筆記的討論圖釘。Apple 端把它們放在這裡，核心沒有這個概念。 */
    fun commentPins(): MutableList<com.kairumo.padnote.comment.CommentPin> =
        com.kairumo.padnote.comment.CommentPinCodec.decodeAll(root.optJSONArray(KEY_COMMENT_PINS))

    /** 寫回圖釘並落盤。其餘欄位原封不動 —— 見這個類別開頭的說明。 */
    fun setCommentPins(
        session: PadnoteSession?,
        pins: List<com.kairumo.padnote.comment.CommentPin>
    ) {
        root.remove(KEY_OBJECT_ENVELOPES)
        root.put(KEY_COMMENT_PINS, com.kairumo.padnote.comment.CommentPinCodec.encodeAll(pins))
        flush(session)
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
        root.remove(KEY_OBJECT_ENVELOPES)
        root.put(KEY_LINKS, com.kairumo.padnote.image.LinkCodec.encodeAll(items))
        flush(session)
    }

    /** 這本筆記頁面上的錄音卡片。核心沒有對應的區塊型別，與連結卡片同一條路。 */
    fun audioCards(): MutableList<com.kairumo.padnote.audio.AudioObject> =
        com.kairumo.padnote.audio.AudioCodec.decodeAll(root.optJSONArray(KEY_AUDIO))

    fun setAudioCards(
        session: PadnoteSession?,
        items: List<com.kairumo.padnote.audio.AudioObject>
    ) {
        root.remove(KEY_OBJECT_ENVELOPES)
        root.put(KEY_AUDIO, com.kairumo.padnote.audio.AudioCodec.encodeAll(items))
        flush(session)
    }

    fun models3D(): MutableList<com.kairumo.padnote.model3d.Model3DObject> =
        com.kairumo.padnote.model3d.Model3DCodec.decodeAll(root.optJSONArray(KEY_MODELS_3D))

    /** 寫回 3D 模型並落盤。其餘欄位原封不動 —— 見這個類別開頭的說明。 */
    fun setModels3D(
        session: PadnoteSession?,
        models: List<com.kairumo.padnote.model3d.Model3DObject>
    ) {
        root.remove(KEY_OBJECT_ENVELOPES)
        root.put(KEY_MODELS_3D, com.kairumo.padnote.model3d.Model3DCodec.encodeAll(models))
        flush(session)
    }

    /** 手寫與文字動態流式錨定清單 (Fluid Sticky Annotations) */
    fun stickyAnchors(): MutableList<StickyAnnotationAnchor> {
        val arr = root.optJSONArray(KEY_STICKY_ANCHORS) ?: return mutableListOf()
        val list = mutableListOf<StickyAnnotationAnchor>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            StickyAnnotationAnchor.fromJsonObject(obj)?.let { list.add(it) }
        }
        return list
    }

    fun setStickyAnchors(session: PadnoteSession?, anchors: List<StickyAnnotationAnchor>) {
        val arr = JSONArray()
        anchors.forEach { arr.put(it.toJsonObject()) }
        root.remove(KEY_OBJECT_ENVELOPES)
        root.put(KEY_STICKY_ANCHORS, arr)
        flush(session)
    }

    /** 遮蔽膠帶清單 (Masking Tape Attachments) */
    fun tapes(): MutableList<com.kairumo.padnote.canvas.NoteTape> =
        com.kairumo.padnote.canvas.NoteTapeCodec.decodeAll(root.optJSONArray(KEY_TAPES))

    fun setTapes(session: PadnoteSession?, items: List<com.kairumo.padnote.canvas.NoteTape>) {
        root.remove(KEY_OBJECT_ENVELOPES)
        root.put(KEY_TAPES, com.kairumo.padnote.canvas.NoteTapeCodec.encodeAll(items))
        flush(session)
    }

    /** 形狀樣式（物件 id → 樣式 JSON）。回傳的是副本，改了不會動到這份中繼資料。 */
    fun shapeStyles(): Map<String, JSONObject> = styleMap(KEY_SHAPE_STYLES)

    fun connectionStyles(): Map<String, JSONObject> = styleMap(KEY_CONNECTION_STYLES)

    /**
     * 增刪形狀與連接線的樣式並落盤（以物件 id 為鍵）。**只動這兩個鍵裡指到的項目**：
     * 每一頁各有自己的形狀儲存，只認得自己那一頁的形狀 —— 整批換掉的話，
     * 換到哪一頁就洗掉其餘頁面的樣式。
     */
    // orphan-ok: 與 shapeStyles/connectionStyles 成對的樣式批次落盤 API，供整本筆記本樣式同步與未來擴充使用
    fun updateStyles(
        session: PadnoteSession?,
        shapeUpserts: Map<String, JSONObject> = emptyMap(),
        shapeRemovals: Set<String> = emptySet(),
        connectionUpserts: Map<String, JSONObject> = emptyMap(),
        connectionRemovals: Set<String> = emptySet()
    ) {
        if (shapeUpserts.isEmpty() && shapeRemovals.isEmpty() &&
            connectionUpserts.isEmpty() && connectionRemovals.isEmpty()) return
        val shapes = root.optJSONObject(KEY_SHAPE_STYLES) ?: JSONObject()
        val links = root.optJSONObject(KEY_CONNECTION_STYLES) ?: JSONObject()
        shapeRemovals.forEach { shapes.remove(it) }
        shapeUpserts.forEach { (k, v) -> shapes.put(k, v) }
        connectionRemovals.forEach { links.remove(it) }
        connectionUpserts.forEach { (k, v) -> links.put(k, v) }
        root.put(KEY_SHAPE_STYLES, shapes)
        root.put(KEY_CONNECTION_STYLES, links)
        flush(session)
    }

    private fun styleMap(key: String): Map<String, JSONObject> {
        val obj = root.optJSONObject(key) ?: return emptyMap()
        val out = LinkedHashMap<String, JSONObject>()
        for (k in obj.keys()) obj.optJSONObject(k)?.let { out[k.lowercase()] = JSONObject(it.toString()) }
        return out
    }

    private fun JSONArray.toStringList(): List<String> =
        (0 until length()).mapNotNull { optString(it).takeIf { s -> s.isNotEmpty() } }
}

/**
 * 手寫與文字動態流式錨定資料結構 (Fluid Sticky Annotations)。
 *
 * 記錄哪些筆劃綁定在特定的文字方塊上。當文字方塊被拖曳或重新排版時，
 * 關聯的手寫筆跡自動同步平移，徹底解決打字造成手寫跑位的痛點。
 */
data class StickyAnnotationAnchor(
    val id: String = java.util.UUID.randomUUID().toString(),
    val pageIndex: Int = 0,
    val targetId: String,
    var strokeIds: List<String> = emptyList(),
    var anchorOriginX: Float = 0f,
    var anchorOriginY: Float = 0f,
    val createdAtMs: Long = System.currentTimeMillis()
) {
    fun toJsonObject(): JSONObject = JSONObject().apply {
        put("id", id)
        put("pageIndex", pageIndex)
        put("targetId", targetId)
        put("strokeIds", JSONArray(strokeIds))
        put("anchorOriginX", anchorOriginX.toDouble())
        put("anchorOriginY", anchorOriginY.toDouble())
        put("createdAtMs", createdAtMs)
    }

    companion object {
        fun fromJsonObject(obj: JSONObject): StickyAnnotationAnchor? {
            val id = obj.optString("id", "")
            val targetId = obj.optString("targetId", "")
            if (id.isEmpty() || targetId.isEmpty()) return null
            val pageIndex = obj.optInt("pageIndex", 0)
            val arr = obj.optJSONArray("strokeIds")
            val strokeIds = if (arr != null) {
                (0 until arr.length()).mapNotNull { arr.optString(it) }
            } else emptyList()
            val anchorOriginX = obj.optDouble("anchorOriginX", 0.0).toFloat()
            val anchorOriginY = obj.optDouble("anchorOriginY", 0.0).toFloat()
            val createdAtMs = obj.optLong("createdAtMs", System.currentTimeMillis())
            return StickyAnnotationAnchor(id, pageIndex, targetId, strokeIds, anchorOriginX, anchorOriginY, createdAtMs)
        }
    }
}
