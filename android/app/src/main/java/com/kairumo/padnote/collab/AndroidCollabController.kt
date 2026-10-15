package com.kairumo.padnote.collab

import android.util.Base64
import com.kairumo.padnote.ink.InkEngine
import com.kairumo.padnote.ink.InkPackageWriter
import com.kairumo.padnote.library.NotebookMeta
import com.kairumo.padnote.text.RichText
import org.json.JSONArray
import org.json.JSONObject
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.PageStyle
import java.util.UUID

/**
 * Android 的即時協同（設計 §7、§8，協定 4）：物件欄位合併、字元層級的文字與格式錨點、逐筆的筆跡、
 * 頁面的增刪搬、每個物件的堆疊順序、加入房間與補發不完整時的整份狀態。
 *
 * 與 Apple 端 `NotebookEditorView` 的協同段落一一對應，線上格式相同。
 * 編輯器以 `remember(notebookId)` 持有一份；**只在主執行緒呼叫**。
 */
class AndroidCollabController(private val manager: CollaborationManager) {

    private val sync = CollabObjectSync()
    private val textHub = CollabTextHub()
    private val ink = CollabInkLedger()

    /** 這次送出的修改是不是正在套用別人的（是的話不再送出）。 */
    val isApplyingRemote: Boolean get() = sync.isApplyingRemote

    /**
     * 遠端套用的結果：編輯器據此重讀畫面。
     * @param needsPublish 整份狀態套用完、有「只有自己有」的物件要補給房間：編輯器接著送出一次。
     */
    data class Applied(val objects: Boolean, val pages: Boolean, val ink: Boolean, val needsPublish: Boolean = false)

    // 整份狀態（設計 §7）
    private var pendingRequest: String? = null
    private var receivedParts = HashSet<Int>()
    private var snapshotKeys = HashSet<String>()
    /** 已經有人回覆的請求：排在後面的人就不必再回（同一份狀態送好幾份只是浪費頻寬）。 */
    private val answered = LinkedHashSet<String>()

    /** 進入（或換）房間：以目前的內容為大家共同的起點，不送出任何東西。 */
    fun reset(canvas: AndroidCollabCanvas, session: PadnoteSession) {
        sync.reset(canvas)
        textHub.reset()
        ink.reset()
        pendingRequest = null
        // 已有的筆畫算「大家都有」—— 否則第一次在某一頁下筆，整頁舊筆畫會被當成新的再送一次。
        for (page in canvas.pageIds) {
            val ids = runCatching { session.visibleStrokeDetails(page) }.getOrDefault(emptyList()).map { it.id }
            ink.known[page] = ids.toHashSet()
        }
    }

    /**
     * 向房間要整份狀態（加入房間、或中繼的暫存已經補不回漏掉的那一段）。
     * 附上自己已有的圖片：回覆的人只需帶我沒有的圖檔。
     */
    fun requestState() {
        val req = UUID.randomUUID().toString()
        pendingRequest = req
        receivedParts = HashSet()
        snapshotKeys = HashSet()
        val blobs = sync.shadow.values.mapNotNull { it["blob"] as? String }.toSet()
        manager.broadcastOplog("state_request", JSONObject()
            .put("proto", PROTO).put("req", req).put("blobs", JSONArray(blobs.toList())))
    }

    // ── 送出 ──

    /** 本機的物件、頁面、頁面設定有變：算出差異送出去（設計 §2.1）。 */
    fun publish(canvas: AndroidCollabCanvas, session: PadnoteSession) {
        if (sync.isApplyingRemote) return
        val me = manager.currentUserId
        val lamport = manager.nextLamport()
        val outgoing = sync.outgoing(canvas, LamportStamp(lamport, me))
        // 文字內容先送：對方先有了新的字，後面帶格式錨點的修改才認得那些字的 id。
        for ((id, old, new) in outgoing.textEdits) {
            val replica = textHub.replica(id, old, me)
            val ops = replica.localEdit(old, new)
            if (ops.isEmpty()) continue
            manager.broadcastOplog("text_ops", JSONObject()
                .put("proto", PROTO).put("id", id).put("base", replica.baseHash).put("text", new)
                .put("ops", JSONArray().also { array -> ops.forEach { array.put(it.toJson()) } }))
        }
        if (outgoing.patches.isEmpty()) return
        val list = JSONArray()
        for (patch in outgoing.patches) {
            val json = patch.toJson()
            val fields = json.getJSONObject("fields")
            val isNew = patch.fields[ObjectPatch.DELETED] == false
            // 新的圖片連位元組一起送，否則對方只收到一個空框。
            if (isNew && patch.type == "image") {
                (sync.shadow[patch.key]?.get("blob") as? String)?.let { blob ->
                    runCatching { session.blobBytes(blob) }.getOrNull()?.let { bytes ->
                        fields.put(BLOB_FIELD, Base64.encodeToString(bytes, Base64.NO_WRAP))
                    }
                }
            }
            if (patch.type == "text") runAnchors(patch)?.let { fields.put(ANCHOR_FIELD, CollabJson.toJson(it)) }
            list.put(json)
        }
        manager.broadcastOplog("obj_patch", JSONObject().put("proto", PROTO).put("patches", list), lamport)
        // 新增（或複製出來）的頁面：上面已有的筆畫也要送，否則對方只看到一張空白頁。
        for (patch in outgoing.patches) {
            if (patch.type == "page" && patch.fields[ObjectPatch.DELETED] == false) publishPageStrokes(session, patch.id)
        }
    }

    /** 這次修改帶了逐字格式：把每段的頭尾換成字的 id（設計 §8.3）。 */
    private fun runAnchors(patch: ObjectPatch): List<List<String>>? {
        val runs = patch.fields["a.runs"] as? List<*> ?: return null
        val text = sync.shadow[patch.key]?.get("text") as? String ?: return null
        val replica = textHub.replica(patch.id, text, manager.currentUserId)
        if (replica.text != text) return null
        val spans = runs.map { r ->
            val m = r as? Map<*, *>
            ((m?.get("start") as? Number)?.toInt() ?: 0) to ((m?.get("length") as? Number)?.toInt() ?: 0)
        }
        return CollabRunAnchors.anchors(spans, replica)
    }

    private fun publishPageStrokes(session: PadnoteSession, page: String) {
        val strokes = runCatching { session.visibleStrokeDetails(page) }.getOrDefault(emptyList())
        val known = ink.known.getOrPut(page) { HashSet() }
        val fresh = strokes.filter { ink.wireId(it.id) !in known }
        if (fresh.isEmpty()) return
        val list = JSONArray()
        val wires = fresh.map { s ->
            val wire = ink.wireId(s.id)
            list.put(CollabStroke.encode(wire, s.tool, s.colorRgba, s.baseWidth, s.points))
            wire
        }
        known += wires
        ink.added(page, wires)
        manager.broadcastOplog("ink_add", JSONObject().put("proto", PROTO).put("page", page).put("strokes", list))
    }

    /** 這一頁的筆跡有變：送出加了哪幾筆、擦了哪幾筆（設計 §4.3）。 */
    fun publishInk(page: String, engine: InkEngine) {
        val current = engine.strokes.mapNotNull { s -> s.coreStrokeId?.let { ink.wireId(it) to s } }
        val ids = current.map { it.first }.toHashSet()
        val known = ink.known[page] ?: HashSet()
        val added = current.filter { it.first !in known }
        val removed = known - ids
        ink.known[page] = ids
        if (added.isNotEmpty()) {
            val list = JSONArray()
            added.forEach { (wire, stroke) -> list.put(CollabStroke.encode(stroke, wire)) }
            ink.added(page, added.map { it.first })
            manager.broadcastOplog("ink_add", JSONObject().put("proto", PROTO).put("page", page).put("strokes", list))
        }
        if (removed.isNotEmpty()) {
            ink.removed(page, removed)
            manager.broadcastOplog("ink_remove", JSONObject().put("proto", PROTO).put("page", page)
                .put("ids", JSONArray(removed.toList())))
        }
    }

    // ── 收到 ──

    /**
     * 套用一個別人的操作。
     *
     * @param canvas 產生一份「現在的筆記本」視角（頁面增刪之後要重新產生，頁面 id 才對）。
     * @param engineFor 畫面上那一頁的筆跡引擎；不在畫面上的頁直接寫進核心。
     * @param later 排一件稍後要做的事（回覆整份狀態時，排在後面的人等一下，看別人回了沒）。
     */
    fun apply(
        op: CollaborationManager.RemoteOplog,
        session: PadnoteSession,
        meta: NotebookMeta,
        canvas: () -> AndroidCollabCanvas,
        engineFor: (String) -> InkEngine?,
        later: (Long, () -> Unit) -> Unit
    ): Applied? {
        val payload = op.payload
        return when (op.kind) {
            "obj_patch" -> {
                val list = payload.optJSONArray("patches") ?: return null
                val patches = (0 until list.length()).mapNotNull { list.optJSONObject(it)?.let(ObjectPatch::fromJson) }
                applyPatches(patches, LamportStamp(op.lamport.toLong(), op.userId), session, meta, canvas)
            }
            "text_ops" -> if (applyTextOps(payload, canvas())) Applied(objects = true, pages = false, ink = false) else null
            "ink_add" -> {
                val page = payload.optString("page").ifEmpty { return null }
                val list = payload.optJSONArray("strokes") ?: return null
                if (addStrokes(page, list, session, canvas().pageIds, engineFor)) Applied(false, false, true) else null
            }
            "ink_remove" -> {
                val page = payload.optString("page").ifEmpty { return null }
                val array = payload.optJSONArray("ids") ?: return null
                val wires = (0 until array.length()).map { array.optString(it) }.toSet()
                if (removeStrokes(page, wires, session, engineFor)) Applied(false, false, true) else null
            }
            "state_request" -> {
                val req = payload.optString("req").ifEmpty { return null }
                // 排名：除了請求者以外，依使用者 id 排序。第一名立刻回，其餘的人依序多等一下 ——
                // 排在前面的人若是舊版（不會回），後面的人照樣會補上。
                val everyone = (manager.peers.map { it.userId } + manager.currentUserId).filter { it != op.userId }.sorted()
                val rank = everyone.indexOf(manager.currentUserId).coerceAtLeast(0)
                val blobsArray = payload.optJSONArray("blobs")
                val blobs = (0 until (blobsArray?.length() ?: 0)).map { blobsArray!!.optString(it) }.toSet()
                later(rank * ANSWER_STAGGER_MS) {
                    if (req !in answered) answerState(req, op.userId, blobs, session, engineFor)
                }
                null
            }
            "state_snapshot" -> {
                val req = payload.optString("req")
                remember(req)
                if (req != pendingRequest || payload.optString("to") != manager.currentUserId) return null
                applySnapshotPart(payload, session, meta, canvas, engineFor)
            }
            else -> null
        }
    }

    private fun remember(req: String) {
        answered += req
        if (answered.size > 64) answered.remove(answered.first())
    }

    private fun addStrokes(
        page: String, list: JSONArray, session: PadnoteSession, pageIds: List<String>, engineFor: (String) -> InkEngine?
    ): Boolean {
        val known = ink.known.getOrPut(page) { HashSet() }
        val now = System.currentTimeMillis()
        val decoded = (0 until list.length()).mapNotNull { list.optJSONObject(it)?.let { j -> CollabStroke.decode(j, now) } }
            .filter { (wire, _) -> wire !in known }
        if (decoded.isEmpty() || page !in pageIds) return false
        val engine = engineFor(page)
        if (engine != null) {
            val added = engine.applyRemoteStrokes(decoded.map { it.second })
            decoded.zip(added).forEach { (d, s) -> s.coreStrokeId?.let { ink.remember(d.first, it) } }
        } else {
            for ((wire, s) in decoded) {
                val local = UUID.randomUUID().toString()
                InkPackageWriter.add(session, page, local, s.tool, s.colorRgba, s.baseWidth, s.points,
                    s.layer.toUByte(), s.lineType.toUByte())
                ink.remember(wire, local)
            }
        }
        known += decoded.map { it.first }
        ink.added(page, decoded.map { it.first })
        return true
    }

    private fun removeStrokes(page: String, wires: Set<String>, session: PadnoteSession, engineFor: (String) -> InkEngine?): Boolean {
        val locals = wires.map { ink.localId(it) }.toSet()
        ink.known[page]?.removeAll(wires)
        ink.removed(page, wires)
        val engine = engineFor(page)
        if (engine != null) return engine.removeRemoteStrokes { it.coreStrokeId in locals } > 0
        locals.forEach { InkPackageWriter.erase(session, page, it) }
        return true
    }

    private fun applyPatches(
        patches: List<ObjectPatch>, stamp: LamportStamp, session: PadnoteSession,
        meta: NotebookMeta, canvas: () -> AndroidCollabCanvas
    ): Applied? {
        if (patches.isEmpty()) return null
        var view = canvas()
        var changed = false
        var pagesChanged = false
        val anchored = mutableListOf<Pair<String, List<*>>>()
        sync.isApplyingRemote = true
        try {
            for (patch in patches) {
                val blob = patch.fields[BLOB_FIELD] as? String
                if (blob != null) runCatching { session.putBlob(Base64.decode(blob, Base64.DEFAULT)) }
                (patch.fields[ANCHOR_FIELD] as? List<*>)?.let { if ("a.runs" in patch.fields) anchored += patch.id to it }
                val clean = patch.copy(fields = patch.fields - BLOB_FIELD - ANCHOR_FIELD)
                if (sync.apply(clean, stamp, view)) {
                    changed = true
                    if (patch.type == "page") pagesChanged = true
                }
            }
            if (!changed) return null
            view = finishRemote(pagesChanged, session, meta, view, canvas)
            for ((id, anchors) in anchored) resolveRunAnchors(id, anchors, view)
            sync.refreshShadow(view)
        } finally {
            sync.isApplyingRemote = false
        }
        return Applied(objects = true, pages = pagesChanged, ink = false)
    }

    /** 寫回之後的收尾：頁面、擱著的物件、堆疊順序。回傳（頁面變了的話）新的視角。 */
    private fun finishRemote(
        pagesChanged: Boolean, session: PadnoteSession, meta: NotebookMeta,
        view: AndroidCollabCanvas, canvas: () -> AndroidCollabCanvas
    ): AndroidCollabCanvas {
        val fresh = if (pagesChanged && reconcilePages(session, meta)) canvas() else view
        sync.retryDeferred(fresh)
        val (orders, under) = sync.desiredStacking()
        fresh.writeStacking(orders, under)
        // 寫回後的編碼要成為新的同步基準，否則下一次本機修改會把這些欄位當成「我改的」再送一次。
        sync.refreshShadow(fresh)
        return fresh
    }

    /** 別人送來的逐字格式：以字的 id 換回自己這邊現在的位置（設計 §8.3）。 */
    private fun resolveRunAnchors(id: String, anchors: List<*>, canvas: AndroidCollabCanvas) {
        val page = sync.shadow["text:$id"]?.get("page") as? String ?: return
        if (page !in canvas.pageIds) return
        val stores = canvas.stores(page)
        val box = stores.text.find(id) ?: return
        val runs = box.runs ?: return
        val pairs = anchors.map { a -> (a as? List<*>)?.map { it as? String ?: "" } ?: emptyList() }
        if (pairs.size != runs.size) return
        val replica = textHub.replica(id, box.text, manager.currentUserId)
        if (replica.text != box.text) return
        val resolved = CollabRunAnchors.resolve(pairs, replica)
        val adjusted = runs.zip(resolved).mapNotNull { (run, span) ->
            span?.let { (start, length) -> run.copy(start = start, length = length) } ?: run
        }
        if (adjusted == runs) return
        stores.text.upsert(box.copy(runs = adjusted))
    }

    /** 依合併後的頁序調整本機的頁面：補上缺的、刪掉被刪的、搬到對的位置（設計 §8.4）。 */
    private fun reconcilePages(session: PadnoteSession, meta: NotebookMeta): Boolean {
        val desired = sync.desiredPageOrder()
        if (desired.isEmpty()) return false
        fun ids(): List<String> {
            val count = runCatching { session.pageCount().toInt() }.getOrDefault(0)
            return (0 until count).mapNotNull { runCatching { session.pageIdAt(it.toUInt()) }.getOrNull() }
        }
        meta.refresh(session)
        var current = ids()
        var changed = false
        val wanted = desired.toSet()
        for (id in current.reversed()) {
            if (id in wanted || current.size <= 1) continue
            val index = current.indexOf(id)
            if (runCatching { session.removePage(id) }.isFailure) continue
            meta.removePageTemplate(session, index, current.size)
            current = ids()
            changed = true
        }
        for ((target, id) in desired.withIndex()) {
            if (id in current) continue
            val paper = sync.shadow["page:$id"]?.get("paper") as? String
            val style = paper?.let { p -> uniffi.padnote_core.paperTemplates().firstOrNull { it.id == p }?.pageStyle }
                ?: PageStyle.BLANK
            if (runCatching { session.addPageWithId(id, style) }.isFailure) continue
            val before = current.size
            val index = minOf(target, before)
            if (index < before) runCatching { session.movePage(id, index.toUInt()) }
            meta.insertPageTemplate(session, index, paper ?: meta.paperId(), before)
            current = ids()
            changed = true
        }
        for ((target, id) in desired.withIndex()) {
            val from = current.indexOf(id)
            if (from < 0 || from == target || target >= current.size) continue
            if (runCatching { session.movePage(id, target.toUInt()) }.isFailure) continue
            meta.movePageData(session, from, target, current.size)
            current = ids()
            changed = true
        }
        return changed
    }

    /** 套用別人在同一個文字方塊打的字（設計 §8.3）。 */
    private fun applyTextOps(payload: JSONObject, canvas: AndroidCollabCanvas): Boolean {
        val id = payload.optString("id").ifEmpty { return false }
        val list = payload.optJSONArray("ops") ?: return false
        val fullText = payload.optString("text")
        val me = manager.currentUserId
        val base = sync.shadow["text:$id"]?.get("text") as? String
        val replica = textHub.replica(id, base ?: return false, me)
        val theirBase = payload.optString("base")
        val newText = if (theirBase.isNotEmpty() && theirBase != replica.baseHash && replica.text == base) {
            // 兩邊的基準對不上（協同開始前就不一致）：以對方的全文為準並重建基準 —— 結果仍一致。
            textHub.rebase(id, fullText, me)
            fullText
        } else {
            for (i in 0 until list.length()) list.optJSONObject(i)?.let(CollabText.Op::fromJson)?.let { replica.apply(it) }
            replica.text
        }
        return replaceText(id, newText, canvas)
    }

    /** 把某個方塊的內容換成 [newText]（格式區段跟著平移），不送出。 */
    private fun replaceText(id: String, newText: String, canvas: AndroidCollabCanvas): Boolean {
        val page = sync.shadow["text:$id"]?.get("page") as? String ?: return false
        if (page !in canvas.pageIds) return false
        val stores = canvas.stores(page)
        val box = stores.text.find(id) ?: return false
        val current = box.text
        if (newText == current) return false
        val updated = box.copy(text = newText)
        RichText.adjustRuns(updated, current)
        val wasApplying = sync.isApplyingRemote
        sync.isApplyingRemote = true
        try {
            stores.text.upsert(updated)
            sync.refreshShadow(canvas)
        } finally {
            sync.isApplyingRemote = wasApplying
        }
        return true
    }

    // ── 整份狀態 ──

    /** 回覆一份整份狀態給 [to]。分段送：一則訊息太大，中繼與手機的連線都吃不消。 */
    private fun answerState(req: String, to: String, blobs: Set<String>, session: PadnoteSession, engineFor: (String) -> InkEngine?) {
        remember(req)
        val items = mutableListOf<Pair<String, JSONObject>>() // ("objects"|"ink", 內容)
        for (entry in sync.snapshot()) {
            val json = entry.toJson()
            if (entry.type == "image") {
                val hash = entry.groups.values.firstNotNullOfOrNull { it["blob"] as? String }
                if (hash != null && hash !in blobs) {
                    runCatching { session.blobBytes(hash) }.getOrNull()?.let { json.put("b64", Base64.encodeToString(it, Base64.NO_WRAP)) }
                }
            }
            items += "objects" to json
        }
        // 筆跡：只帶這次協同期間加入與擦掉的 —— 之前就有的兩邊都有（設計 §8.1）。
        val pages = ink.sessionAdded.keys + ink.sessionRemoved.keys
        for (page in pages) {
            val wanted = ink.sessionAdded[page] ?: emptySet<String>()
            val strokes = JSONArray()
            if (wanted.isNotEmpty()) {
                val engine = engineFor(page)
                if (engine != null) {
                    for (s in engine.strokes) {
                        val wire = s.coreStrokeId?.let { ink.wireId(it) } ?: continue
                        if (wire in wanted) strokes.put(CollabStroke.encode(s, wire))
                    }
                } else {
                    for (s in runCatching { session.visibleStrokeDetails(page) }.getOrDefault(emptyList())) {
                        val wire = ink.wireId(s.id)
                        if (wire in wanted) strokes.put(CollabStroke.encode(wire, s.tool, s.colorRgba, s.baseWidth, s.points))
                    }
                }
            }
            items += "ink" to JSONObject().put("page", page).put("strokes", strokes)
                .put("removed", JSONArray((ink.sessionRemoved[page] ?: emptySet<String>()).toList()))
        }
        val parts = mutableListOf<Pair<JSONArray, JSONArray>>()
        var objects = JSONArray()
        var inkList = JSONArray()
        var size = 0
        for ((kind, json) in items) {
            val length = json.toString().length
            if (size > 0 && size + length > PART_BYTES) {
                parts += objects to inkList
                objects = JSONArray(); inkList = JSONArray(); size = 0
            }
            if (kind == "objects") objects.put(json) else inkList.put(json)
            size += length
        }
        parts += objects to inkList
        for ((index, part) in parts.withIndex()) {
            manager.broadcastOplog("state_snapshot", JSONObject()
                .put("proto", PROTO).put("req", req).put("to", to)
                .put("part", index).put("parts", parts.size)
                .put("objects", part.first).put("ink", part.second))
        }
    }

    /** 收到整份狀態的一段。全部收齊後，把「只有自己有」的物件交給下一次送出補給房間。 */
    private fun applySnapshotPart(
        payload: JSONObject, session: PadnoteSession, meta: NotebookMeta,
        canvas: () -> AndroidCollabCanvas, engineFor: (String) -> InkEngine?
    ): Applied? {
        val part = payload.optInt("part", -1)
        val parts = payload.optInt("parts", 1)
        if (part < 0 || !receivedParts.add(part)) return null
        val list = payload.optJSONArray("objects") ?: JSONArray()
        val entries = (0 until list.length()).mapNotNull { i ->
            val json = list.optJSONObject(i) ?: return@mapNotNull null
            json.optString("b64").takeIf { it.isNotEmpty() }?.let { b64 ->
                runCatching { session.putBlob(Base64.decode(b64, Base64.DEFAULT)) }
            }
            SnapshotEntry.fromJson(json)
        }
        snapshotKeys += entries.map { "${it.type}:${it.id}" }
        var view = canvas()
        var pagesChanged = false
        var inkChanged = false
        sync.isApplyingRemote = true
        try {
            val result = sync.applySnapshot(entries, view)
            pagesChanged = entries.any { it.type == "page" }
            view = finishRemote(pagesChanged, session, meta, view, canvas)
            for ((id, text) in result.textOverrides) {
                textHub.rebase(id, text, manager.currentUserId)
                replaceText(id, text, view)
            }
            val inkList = payload.optJSONArray("ink") ?: JSONArray()
            for (i in 0 until inkList.length()) {
                val pageInk = inkList.optJSONObject(i) ?: continue
                val page = pageInk.optString("page")
                if (page.isEmpty()) continue
                pageInk.optJSONArray("strokes")?.let { if (addStrokes(page, it, session, view.pageIds, engineFor)) inkChanged = true }
                val removed = pageInk.optJSONArray("removed")
                val wires = (0 until (removed?.length() ?: 0)).map { removed!!.optString(it) }.toSet()
                if (wires.isNotEmpty() && removeStrokes(page, wires, session, engineFor)) inkChanged = true
            }
            sync.refreshShadow(view)
        } finally {
            sync.isApplyingRemote = false
        }
        var needsPublish = false
        if (receivedParts.size >= parts) {
            pendingRequest = null
            // 只有自己有的物件（例如離線時新增的）：忘掉它們，下一次送出就會當成新的補給房間。
            val localOnly = sync.liveKeys.filter { it !in snapshotKeys && !it.startsWith("meta:") }
            sync.forget(localOnly)
            needsPublish = localOnly.isNotEmpty()
        }
        return Applied(objects = true, pages = pagesChanged, ink = inkChanged, needsPublish = needsPublish)
    }

    private companion object {
        const val PROTO = 4
        /** 新圖片的位元組（base64），只在建立時帶（與 Apple 端 `CollabObjectSync.blobField` 相同）。 */
        const val BLOB_FIELD = "#blob"
        /** 逐字格式的錨點（與 Apple 端 `CollabObjectSync.anchorField` 相同）。 */
        const val ANCHOR_FIELD = "#ra"
        /** 整份狀態每段的大約上限（字元數）。 */
        const val PART_BYTES = 400_000
        /** 回覆整份狀態時，排名每多一位多等的時間。 */
        const val ANSWER_STAGGER_MS = 700L
    }
}
