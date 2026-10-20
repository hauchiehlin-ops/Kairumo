package com.kairumo.padnote.collab

import com.kairumo.padnote.chart.ChartAppearance
import com.kairumo.padnote.chart.ChartObject
import com.kairumo.padnote.chart.ChartStore
import com.kairumo.padnote.image.ImageAppearance
import com.kairumo.padnote.image.ImageStore
import com.kairumo.padnote.image.NoteImage
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.shape.NoteConnection
import com.kairumo.padnote.shape.NoteShape
import com.kairumo.padnote.shape.ShapeStore
import com.kairumo.padnote.shape.ShapeStyleMeta
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.TableAppearance
import com.kairumo.padnote.table.TableStore
import com.kairumo.padnote.text.TextBox
import com.kairumo.padnote.text.TextBoxAppearance
import com.kairumo.padnote.text.TextBoxStore
import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.StrokePoint
import uniffi.padnote_core.ToolKind
import kotlin.math.abs

/** 一頁的物件儲存。目前這一頁用編輯器手上那一組（畫面才會跟著變），其餘頁面臨時開一組。 */
class CollabPageStores(
    val text: TextBoxStore,
    val image: ImageStore,
    val table: TableStore,
    val chart: ChartStore,
    val shape: ShapeStore
) {
    companion object {
        fun load(session: PadnoteSession, pageId: String) = CollabPageStores(
            TextBoxStore(session, pageId), ImageStore(session, pageId), TableStore(session, pageId),
            ChartStore(session, pageId), ShapeStore(session, pageId)
        ).also { it.text.load(); it.image.load(); it.table.load(); it.chart.load(); it.shape.load() }
    }
}

/**
 * Android 的筆記本 ⇄ 協同的線上欄位（設計 §8.2）。
 *
 * 欄位與 Apple 端 `CollabCanonical` 逐項相同：外觀 JSON 攤平成 `a.` 前綴、形狀與連接線的樣式是 `s.`、
 * 連結卡片等清單項目是 `p.`。每次比對都新建一個（它只是「現在的筆記本」的一個視角）。
 *
 * @param scope 這次比對的頁面（[maps] 的 `allPages = false`）：單頁模式是目前這一頁，連續模式是
 *   畫面上載入過的那幾頁 —— 其餘頁面本機改不到，掃它們只是浪費。
 * @param live 畫面上正在用的那一組儲存（寫回要進它們，畫面才會跟著變）；沒有的頁面臨時開一組。
 */
class AndroidCollabCanvas(
    private val session: PadnoteSession,
    private val meta: NotebookMeta,
    private val scope: List<String>,
    private val live: (String) -> CollabPageStores?
) : CollabCanvas {

    private val others = HashMap<String, CollabPageStores>()

    override val pageIds: List<String> by lazy {
        val count = runCatching { session.pageCount().toInt() }.getOrDefault(0)
        (0 until count).mapNotNull { runCatching { session.pageIdAt(it.toUInt()) }.getOrNull() }
    }

    /** 某一頁的物件儲存（目前這一頁是編輯器手上那一組）。 */
    fun stores(pageId: String): CollabPageStores =
        live(pageId) ?: others.getOrPut(pageId) { CollabPageStores.load(session, pageId) }

    // ── 編碼 ──

    override fun maps(
        pagePositions: Map<String, String>, zPositions: Map<String, String>, allPages: Boolean
    ): Map<String, CollabEntry> {
        meta.refresh(session)
        val out = LinkedHashMap<String, CollabEntry>()
        val ids = pageIds
        val under = underIds(ids)
        val locked = lockedIds()
        fun add(type: String, id: String, dict: Map<String, Any>) {
            val canonical = canonicalId(id)
            val full = dict.toMutableMap()
            // 堆疊順序與「在筆跡下方」是每個物件自己的欄位：兩人同時調不同物件的層級，兩邊都留下（設計 §8.7）。
            full["under"] = canonical in under
            // 「鎖定在畫布上」比照辦理：鎖定 / 解除各是那個物件自己的一個欄位。
            full["locked"] = canonical in locked
            zPositions[canonical]?.let { full["z"] = it }
            out["$type:$canonical"] = CollabEntry(type, canonical, full)
        }
        val pages = if (allPages) ids else scope.filter { it in ids }
        for (page in pages) {
            val s = stores(page)
            for (box in s.text.all) {
                val dict = CollabJson.flatten(JSONObject(TextBoxAppearance.encode(box)), "a.").toMutableMap()
                dict["page"] = page; dict["x"] = box.x.toDouble(); dict["y"] = box.y.toDouble(); dict["text"] = box.text
                add("text", box.id, dict)
            }
            for (image in s.image.all) {
                val dict = CollabJson.flatten(JSONObject(ImageAppearance.encode(image)), "a.").toMutableMap()
                dict["page"] = page; dict["x"] = image.x.toDouble(); dict["y"] = image.y.toDouble()
                dict["blob"] = image.blobId
                // Apple 以檔名存圖：沒有檔名的（核心直接插入的）以 blob id 命名，否則對方存不下來。
                if ((dict["a.image.fileName"] as? String).isNullOrEmpty()) dict["a.image.fileName"] = "${image.blobId}.png"
                add("image", image.id, dict)
            }
            // 圖表在 Apple 端是「帶圖表設定的圖片」，線上也是 `image`（`a.object = chart`）。
            for (chart in s.chart.all) {
                val json = JSONObject(ChartAppearance.encode(chart.spec, chart.width, chart.height))
                val dict = CollabJson.flatten(json, "a.").toMutableMap()
                dict["page"] = page; dict["x"] = chart.x.toDouble(); dict["y"] = chart.y.toDouble()
                runCatching { session.blockBlobId(chart.id) }.getOrNull()?.let { dict["blob"] = it }
                add("image", chart.id, dict)
            }
            for (table in s.table.all) {
                val dict = CollabJson.flatten(JSONObject(TableAppearance.encode(table)), "a.").toMutableMap()
                dict.remove("a.table.id")
                dict["page"] = page
                add("table", table.id, dict)
            }
            for (shape in s.shape.all) {
                val dict = CollabJson.flatten(ShapeStyleMeta.encode(shape), "s.").toMutableMap()
                dict["page"] = page
                dict["x"] = shape.x.toDouble(); dict["y"] = shape.y.toDouble()
                dict["width"] = shape.width.toDouble(); dict["height"] = shape.height.toDouble()
                dict["rotation"] = (shape.rotationDegrees ?: 0f).toDouble()
                add("shape", shape.id, dict)
            }
            for (link in s.shape.allConnections) {
                val dict = CollabJson.flatten(ShapeStyleMeta.encode(link), "s.").toMutableMap()
                dict["page"] = page
                dict["from"] = canonicalId(link.fromShapeId)
                dict["to"] = canonicalId(link.toShapeId)
                add("connection", link.id, dict)
            }
        }
        val scopeSet = pages.toSet()
        for ((type, key) in NotebookMeta.PAYLOAD_KEYS) {
            val array = meta.raw(key) as? JSONArray ?: continue
            for (i in 0 until array.length()) {
                val item = array.optJSONObject(i) ?: continue
                val id = item.optString("id")
                if (id.isEmpty()) continue
                val page = ids.getOrNull(item.optInt("pageIndex", -1)) ?: continue
                if (page !in scopeSet) continue
                val json = JSONObject(item.toString()).apply { remove("id"); remove("pageIndex") }
                val dict = CollabJson.flatten(json, "p.").toMutableMap()
                dict["page"] = page
                add(type, id, dict)
            }
        }
        for ((index, id) in ids.withIndex()) {
            val dict = HashMap<String, Any>()
            pagePositions[id]?.let { dict["pos"] = it }
            dict["paper"] = meta.paperId(index)
            out["page:$id"] = CollabEntry("page", id, dict)
        }
        // 頁面層級的設定（核取方塊等；Android 目前沒有）。堆疊順序已改成每個物件的欄位。
        out["meta:notebook"] = CollabEntry("meta", "notebook", emptyMap())
        return out
    }

    private fun pageKeyedLists(key: String, ids: List<String>): Map<String, List<String>> {
        val byPage = meta.raw(key) as? JSONObject ?: return emptyMap()
        val out = LinkedHashMap<String, List<String>>()
        for (pageKey in byPage.keys()) {
            val page = pageKey.toIntOrNull()?.let { ids.getOrNull(it) } ?: continue
            val list = byPage.optJSONArray(pageKey) ?: continue
            out[page] = (0 until list.length()).mapNotNull { list.optString(it).ifEmpty { null }?.let(::canonicalId) }
        }
        return out
    }

    private fun underIds(ids: List<String>): Set<String> =
        pageKeyedLists(NotebookMeta.KEY_UNDER_INK_BY_PAGE, ids).values.flatten().toSet()

    /** 鎖定的物件（不分頁，與 [NotebookMeta.lockedObjectIds] 一樣）。頁次鍵對不上現有頁面的也算。 */
    private fun lockedIds(): Set<String> {
        val byPage = meta.raw(NotebookMeta.KEY_LOCKED_BY_PAGE) as? JSONObject ?: return emptySet()
        val out = HashSet<String>()
        for (pageKey in byPage.keys()) {
            val list = byPage.optJSONArray(pageKey) ?: continue
            for (i in 0 until list.length()) list.optString(i).ifEmpty { null }?.let { out += canonicalId(it) }
        }
        return out
    }

    override fun objectOrders(): Map<String, List<String>> {
        meta.refresh(session)
        return pageKeyedLists(NotebookMeta.KEY_ORDER_BY_PAGE, pageIds)
    }

    override fun writeStacking(
        orders: Map<String, List<String>>, under: Map<String, List<String>>, locked: Map<String, List<String>>
    ) {
        val ids = pageIds
        val local = localIds()
        fun encode(lists: Map<String, List<String>>, sorted: Boolean = false): JSONObject? {
            val byPage = JSONObject()
            for ((page, list) in lists) {
                val index = ids.indexOf(page)
                if (index < 0 || list.isEmpty()) continue
                val localList = list.map { local[it] ?: it }
                byPage.put(index.toString(), JSONArray(if (sorted) localList.sorted() else localList))
            }
            return if (byPage.length() == 0) null else byPage
        }
        // 鎖定名單在檔案裡是排序過的本機 id（`NotebookMeta.setObjectLocked`）。
        for ((key, wanted) in listOf(
            NotebookMeta.KEY_ORDER_BY_PAGE to encode(orders),
            NotebookMeta.KEY_UNDER_INK_BY_PAGE to encode(under),
            NotebookMeta.KEY_LOCKED_BY_PAGE to encode(locked, sorted = true),
        )) {
            if ((meta.raw(key)?.toString() ?: "") != (wanted?.toString() ?: "")) meta.setRaw(session, key, wanted)
        }
    }

    override fun inScope(type: String, dict: Map<String, Any>): Boolean {
        if (type == "page") return true
        if (type !in KNOWN_TYPES) return false // 這一版畫不出來的型別：不在畫面上不代表被刪除
        return dict["page"] in scope
    }

    // ── 寫回 ──

    override fun write(type: String, id: String, fields: Map<String, Any>, deleted: Boolean): Boolean {
        val ids = pageIds
        if (type == "page") {
            val index = ids.indexOf(id)
            val paper = fields["paper"] as? String
            if (!deleted && index >= 0 && paper != null && meta.paperId(index) != paper) {
                meta.setPagePaperId(session, index, paper, ids.size)
            }
            return true // 頁面的新增、刪除、搬動由編輯器依 `desiredPageOrder` 調整
        }
        if (type == "meta") return true // 堆疊順序由 writeStacking 寫回；其餘頁面設定 Android 沒有
        NotebookMeta.PAYLOAD_KEYS[type]?.let { key -> return writePayload(key, id, fields, deleted, ids) }
        if (type !in KNOWN_TYPES) return true // 認不得的型別：留在合併狀態裡，不顯示

        if (deleted) {
            // 合併狀態裡通常還記得它在哪一頁；不記得才每一頁找一次（物件 id 全本唯一）。
            val known = (fields["page"] as? String)?.takeIf { it in ids }
            if (known != null && removeFrom(stores(known), type, id)) return true
            for (page in ids) if (page != known && removeFrom(stores(page), type, id)) break
            return true
        }
        val page = fields["page"] as? String ?: return false
        if (page !in ids) return false
        val s = stores(page)
        fun number(key: String): Float? = (fields[key] as? Number)?.toFloat()
        val appearance = CollabJson.unflatten(fields, "a.")

        when (type) {
            "text" -> {
                val existing = s.text.find(id)
                // 從預設值開始套：外觀裡沒有的鍵 = 對方清掉了（例如邊框色回到預設）。
                val box = TextBox(id = id, text = existing?.text ?: (fields["text"] as? String ?: ""))
                TextBoxAppearance.apply(appearance.toString(), box)
                box.x = number("x") ?: existing?.x ?: box.x
                box.y = number("y") ?: existing?.y ?: box.y
                s.text.upsert(box)
            }
            "image" -> {
                if (appearance.optString("object") == "chart") {
                    val spec = ChartAppearance.decode(appearance.toString()) ?: return true
                    val existing = s.chart.find(id)
                    val chart = ChartObject(id = id, spec = spec,
                        x = number("x") ?: existing?.x ?: 60f, y = number("y") ?: existing?.y ?: 120f)
                    ChartAppearance.size(appearance.toString())?.let { (w, h) -> chart.width = w; chart.height = h }
                    s.chart.upsert(chart)
                    return true
                }
                val existing = s.image.find(id)
                val blob = fields["blob"] as? String ?: existing?.blobId ?: return false
                val image = NoteImage(id = id, blobId = blob)
                ImageAppearance.apply(appearance.toString(), image)
                image.x = number("x") ?: existing?.x ?: image.x
                image.y = number("y") ?: existing?.y ?: image.y
                s.image.upsert(image)
            }
            "table" -> {
                val json = appearance.optJSONObject("table") ?: return true
                json.put("id", id)
                val table = NoteTable.decode(json.toString()) ?: return true
                s.table.upsert(table)
            }
            "shape" -> {
                val style = CollabJson.unflatten(fields, "s.")
                val previousGroup = s.shape.find(id)?.groupId
                val shape = (s.shape.find(id)?.copy() ?: NoteShape(id = id))
                ShapeStyleMeta.apply(style, shape)
                shape.groupId = style.optString("groupId").ifEmpty { null }
                number("x")?.let { shape.x = it }
                number("y")?.let { shape.y = it }
                number("width")?.let { shape.width = it }
                number("height")?.let { shape.height = it }
                number("rotation")?.let { shape.rotationDegrees = if (abs(it) > 0.01f) it else null }
                s.shape.upsert(shape)
                // 群組是核心物件樹的節點：成員變了就整組重建（新舊兩個群組都要）。
                if (previousGroup != shape.groupId) s.shape.regroup(setOfNotNull(previousGroup, shape.groupId))
            }
            "connection" -> {
                val from = fields["from"] as? String ?: return false
                val to = fields["to"] as? String ?: return false
                val link = s.shape.findConnection(id)?.copy(fromShapeId = from, toShapeId = to)
                    ?: NoteConnection(id = id, fromShapeId = from, toShapeId = to)
                ShapeStyleMeta.apply(CollabJson.unflatten(fields, "s."), link)
                return s.shape.upsertConnection(link) // 兩端的形狀還沒到：晚點再試
            }
        }
        return true
    }

    private fun removeFrom(s: CollabPageStores, type: String, id: String): Boolean {
        when (type) {
            "text" -> s.text.find(id)?.let { s.text.remove(it); return true }
            "image" -> {
                s.image.find(id)?.let { s.image.remove(it); return true }
                s.chart.find(id)?.let { s.chart.remove(it); return true }
            }
            "table" -> s.table.find(id)?.let { s.table.remove(it); return true }
            "shape" -> s.shape.find(id)?.let { s.shape.remove(it); return true }
            "connection" -> s.shape.findConnection(id)?.let { s.shape.remove(it); return true }
        }
        return false
    }

    private fun writePayload(key: String, id: String, fields: Map<String, Any>, deleted: Boolean, ids: List<String>): Boolean {
        val array = meta.raw(key) as? JSONArray ?: JSONArray()
        val items = (0 until array.length()).mapNotNull { array.optJSONObject(it) }.toMutableList()
        val index = items.indexOfFirst { canonicalId(it.optString("id")) == id }
        if (deleted) {
            if (index < 0) return true
            items.removeAt(index)
        } else {
            val page = ids.indexOf(fields["page"] as? String ?: return false)
            if (page < 0) return false
            val json = CollabJson.unflatten(fields, "p.")
            json.put("id", if (index >= 0) items[index].optString("id") else id)
            json.put("pageIndex", page)
            if (index >= 0) items[index] = json else items += json
        }
        meta.setRaw(session, key, JSONArray(items))
        return true
    }

    /** 正規 id → 本機 id（Apple 寫進來的清單項目 id 可能是大寫 UUID）。 */
    private fun localIds(): Map<String, String> {
        val local = HashMap<String, String>()
        for (key in NotebookMeta.PAYLOAD_KEYS.values) {
            val array = meta.raw(key) as? JSONArray ?: continue
            for (i in 0 until array.length()) {
                val raw = array.optJSONObject(i)?.optString("id")?.ifEmpty { null } ?: continue
                local[canonicalId(raw)] = raw
            }
        }
        return local
    }

    companion object {
        /** Android 這一版畫得出來、也編碼得出來的物件型別（清單項目另見 `NotebookMeta.PAYLOAD_KEYS`）。 */
        private val KNOWN_TYPES = setOf("text", "image", "table", "shape", "connection") +
            NotebookMeta.PAYLOAD_KEYS.keys

        fun canonicalId(raw: String): String = ShapeStore.stableBlockId(raw)
    }
}

/**
 * 筆畫的線上格式（設計 §8.1）：核心的 `StrokePoint`，每點 7 個數字。與 Apple 端 `CollabStroke` 相同。
 */
object CollabStroke {

    fun encode(stroke: InkEngine.CompletedStroke, id: String): JSONObject =
        encode(id, stroke.tool, stroke.colorRgba, stroke.baseWidth, stroke.points)

    fun encode(id: String, tool: ToolKind, colorRgba: ByteArray, baseWidth: Float, strokePoints: List<StrokePoint>): JSONObject {
        val points = JSONArray()
        for (p in strokePoints) {
            points.put(p.x.toDouble()); points.put(p.y.toDouble()); points.put(p.pressure.toDouble())
            points.put(p.tilt.toDouble()); points.put(p.azimuth.toDouble()); points.put(p.dtUs.toDouble())
            points.put(p.roll.toDouble())
        }
        return JSONObject()
            .put("id", id)
            .put("tool", tool.name.lowercase())
            .put("rgba", "#" + colorRgba.joinToString("") { "%02X".format(it.toInt() and 0xFF) })
            .put("width", baseWidth.toDouble())
            .put("points", points)
    }

    /** 回傳 `(線上 id, 筆畫)`；格式不對的回 `null`。 */
    fun decode(json: JSONObject, startedAtMs: Long): Pair<String, InkEngine.CompletedStroke>? {
        val id = json.optString("id").ifEmpty { return null }
        val tool = runCatching { ToolKind.valueOf(json.optString("tool").uppercase()) }.getOrNull() ?: return null
        val flat = json.optJSONArray("points") ?: return null
        if (flat.length() < 7) return null
        val points = ArrayList<StrokePoint>(flat.length() / 7)
        var i = 0
        while (i + 6 < flat.length()) {
            points += StrokePoint(
                flat.optDouble(i).toFloat(), flat.optDouble(i + 1).toFloat(), flat.optDouble(i + 2).toFloat(),
                flat.optDouble(i + 3).toFloat(), flat.optDouble(i + 4).toFloat(),
                maxOf(0.0, flat.optDouble(i + 5)).toLong().toUInt(), flat.optDouble(i + 6).toFloat()
            )
            i += 7
        }
        val stroke = InkEngine.CompletedStroke(
            pointerId = ULong.MAX_VALUE - 1_000_000uL - (id.hashCode().toULong() and 0xFFFFFuL),
            coreStrokeId = null,
            points = points,
            tool = tool,
            startedAtMs = startedAtMs,
            colorRgba = rgba(json.optString("rgba")),
            baseWidth = json.optDouble("width", 3.0).toFloat()
        )
        return id to stroke
    }

    private fun rgba(hex: String): ByteArray {
        val clean = hex.removePrefix("#")
        val bytes = clean.chunked(2).take(4).map { (it.toIntOrNull(16) ?: 0).toByte() }.toMutableList()
        while (bytes.size < 4) bytes += (-1).toByte()
        return bytes.toByteArray()
    }
}
