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

    /** 分塊送來的大圖（`state_blob`）收到一半的進度。由編輯器設定（要知道暫存資料夾與核心）。 */
    var blobAssembler: CollabBlobAssembler? = null

    /** 已經提醒過「整本超過寄存上限」的房間（每個房間只提醒一次）。 */
    private var warnedTooLarge: String? = null

    /** 這次送出的修改是不是正在套用別人的（是的話不再送出）。 */
    val isApplyingRemote: Boolean get() = sync.isApplyingRemote

    /**
     * 遠端套用的結果：編輯器據此重讀畫面。
     * @param needsPublish 整份狀態套用完、有「只有自己有」的物件要補給房間：編輯器接著送出一次。
     */
    data class Applied(val objects: Boolean, val pages: Boolean, val ink: Boolean, val needsPublish: Boolean = false)

    // 整份狀態（設計 §7）
    private var pendingRequest: String? = null
    /**
     * 每一次請求各自收到的段號（與 Apple `CollabStateSync.partsByRequest` 相同）。
     *
     * 以前全部共用一個集合，而且每次 `requestState()` 都清空：重試迴圈發出第二次請求時第一次的回覆
     * 還在路上，兩份回覆的段落混著計數 ——「收齊」與「房間裡有哪些物件」都只剩其中幾段，
     * 房主還在等筆畫補上的頁被當成「只有自己有的空白頁」刪掉，加入者只剩第一頁。
     */
    private val partsByRequest = HashMap<String, HashSet<Int>>()
    /** 每一次請求採用的回覆者（與 Apple `CollabStateSync.responderByRequest` 相同）。 */
    private val responderByRequest = HashMap<String, String>()
    /** 這個房間收過的**任何一份**整份狀態（寄存的、每一次回覆的）裡出現過的鍵。換房間才清。 */
    private var roomKeys = HashSet<String>()
    // 中繼寄存的整份狀態（`state_store`）的計段，與自己發出的請求分開。
    private var storedSnap: String? = null
    private var storedParts = HashSet<Int>()
    /** 已經有人回覆的請求：排在後面的人就不必再回（同一份狀態送好幾份只是浪費頻寬）。 */
    private val answered = LinkedHashSet<String>()

    /**
     * 每一頁「上一次比對時，這個引擎上確實有的筆畫」（線上 id）。
     *
     * 擦除只認這裡面有、現在沒了的筆畫 —— 不是「已知的筆畫裡引擎上沒有的」。後者在換頁、
     * 整份狀態套用後頁面重排、引擎還沒從套件讀完的那一瞬間全部成立，結果是把整頁筆畫當成
     * 「被擦掉」廣播出去，房主那邊的筆跡跟著被擦光（墓碑不會復活，I3）。
     */
    private val engineSeen = HashMap<String, Pair<InkEngine, MutableSet<String>>>()

    /**
     * 每一頁擦掉過的筆畫 id（頁面 → 線上／核心 id）：核心的墓碑（`removedStrokeIds`，每頁讀一次）
     * 加上這次連線送出、收到的擦除。所有放入筆畫的路徑都先查它，回覆與寄存整份狀態時也附上。
     *
     * 以前只靠「這次協同期間擦掉的」：較舊的整份狀態（雲端中繼寄存的那一份、斷線重連的補發、
     * 擦除前就開始收集、擦除後才抵達的回覆）會把已擦掉的筆畫當成新的再放進引擎 —— 畫面上又出現，
     * 核心卻以墓碑為準（I3），兩邊不一致（實機：雲端協作時房主擦掉協作者的字，協作者那台有一頁擦不掉；
     * 斷線重新加入後擦掉的筆跡全部回來）。與 Apple `CollabInkTombstones` 相同。只在主執行緒動。
     */
    private val coreTombstones = HashMap<String, Set<String>>()
    private val erasedHere = HashMap<String, MutableSet<String>>()

    private fun tombstonesFor(page: String, session: PadnoteSession): Set<String> {
        val key = AndroidCollabCanvas.canonicalPageId(page)
        val core = coreTombstones.getOrPut(key) {
            runCatching { session.removedStrokeIds(page) }.getOrDefault(emptyList())
                .mapTo(HashSet()) { it.lowercase() }
        }
        val here = erasedHere[key] ?: return core
        return core + here
    }

    private fun recordTombstones(page: String, ids: Collection<String>) {
        if (ids.isEmpty()) return
        val set = erasedHere.getOrPut(AndroidCollabCanvas.canonicalPageId(page)) { HashSet() }
        for (id in ids) {
            set += id.lowercase()
            set += ink.localId(id).lowercase()
        }
    }
    private val sentRequests = HashSet<String>()

    /** 這個房間的整份狀態已經完整收過一次。沒收到之前，編輯器會定時重新要（見 `EditorCanvasContext`）。 */
    @Volatile var syncedOnce = false
        private set

    /** 還有一份整份狀態的請求在等回覆。 */
    val hasPendingRequest: Boolean get() = pendingRequest != null

    /** 進入（或換）房間：以目前的內容為大家共同的起點，不送出任何東西。 */
    fun reset(canvas: AndroidCollabCanvas, session: PadnoteSession, preservePendingRequest: Boolean = false) {
        sync.reset(canvas)
        textHub.reset()
        ink.reset()
        engineSeen.clear()
        coreTombstones.clear()
        erasedHere.clear()
        pendingInk.clear()
        if (!preservePendingRequest) {
            pendingRequest = null
            sentRequests.clear()
            partsByRequest.clear()
            responderByRequest.clear()
            roomKeys = HashSet()
            syncedOnce = false
        }
        storedSnap = null
        storedParts = HashSet()
        blobAssembler?.reset()
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
        sentRequests += req
        if (sentRequests.size > 16) sentRequests.remove(sentRequests.first())
        // 不清掉之前請求的段落：那幾份回覆可能還在路上，各自計段（見 `partsByRequest`）。
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
            list.put(CollabStroke.encode(wire, s.tool, s.colorRgba, s.baseWidth, s.points, s.id))
            wire
        }
        known += wires
        ink.added(page, wires)
        manager.broadcastOplog("ink_add", JSONObject().put("proto", PROTO).put("page", page).put("strokes", list))
    }

    /** 這一頁的筆跡有變：送出加了哪幾筆、擦了哪幾筆（設計 §4.3）。 */
    fun publishInk(page: String, engine: InkEngine) {
        // 還沒從套件讀完的引擎（剛換頁、剛加頁）：手上的筆畫不代表這一頁的內容，先不比。
        if (!engine.hasLoaded || engine.pageKey != page) return
        val current = engine.strokes.mapNotNull { s -> s.coreStrokeId?.let { ink.wireId(it) to s } }
        val ids = current.map { it.first }.toHashSet()
        val known = ink.known[page] ?: HashSet()
        val added = current.filter { it.first !in known }
        val previous = engineSeen[page]?.takeIf { it.first === engine }?.second
        val removed = CollabInkDiff.removed(known, ids, previous)
        ink.known[page] = CollabInkDiff.nextKnown(known, ids, removed)
        engineSeen[page] = engine to ids.toHashSet()
        if (added.isNotEmpty()) {
            val list = JSONArray()
            added.forEach { (wire, stroke) -> list.put(CollabStroke.encode(stroke, wire)) }
            ink.added(page, added.map { it.first })
            manager.broadcastOplog("ink_add", JSONObject().put("proto", PROTO).put("page", page).put("strokes", list))
        }
        if (removed.isNotEmpty()) {
            ink.removed(page, removed)
            recordTombstones(page, removed)
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
                applyPatches(patches, LamportStamp(op.lamport.toLong(), op.userId), session, meta, canvas, engineFor)
            }
            "text_ops" -> if (applyTextOps(payload, canvas())) Applied(objects = true, pages = false, ink = false) else null
            "ink_add" -> {
                val page = payload.optString("page").ifEmpty { return null }
                val list = payload.optJSONArray("strokes") ?: return null
                if (addStrokes(page, list, session, engineFor)) {
                    com.kairumo.padnote.canvas.ThumbnailFreshness.markDirty(page)
                    Applied(false, false, true)
                } else null
            }
            "ink_remove" -> {
                val page = payload.optString("page").ifEmpty { return null }
                val array = payload.optJSONArray("ids") ?: return null
                val wires = (0 until array.length()).map { array.optString(it) }.toSet()
                if (removeStrokes(page, wires, session, engineFor)) {
                    com.kairumo.padnote.canvas.ThumbnailFreshness.markDirty(page)
                    Applied(false, false, true)
                } else null
            }
            "state_request" -> {
                val req = payload.optString("req").ifEmpty { return null }
                // 誰來回：**房主優先**。以前依使用者 id 排序、第一名先回 —— 第一名常是另一位協作者，
                // 他自己可能也剛重連、只同步到一半；他一回，房主就不再回，重連的人拿到不完整的那一份
                // （實機：協作者斷線再連，看不到其他人先前的修改，房主的畫面卻都對）。
                // 房主在線時，協作者只在自己完整同步過、而且房主遲遲沒回時才補回。與 Apple 相同。
                val me = manager.currentUserId
                val requester = op.userId
                val ownerOnline = manager.peers.any { it.role == "owner" && it.userId != requester }
                val delayMs = when {
                    manager.isHost -> 0L
                    ownerOnline -> {
                        if (!syncedOnce) return null
                        val others = (manager.peers.filter { it.role != "owner" && it.userId != requester }
                            .map { it.userId } + me).sorted()
                        HOST_GRACE_MS + others.indexOf(me).coerceAtLeast(0) * ANSWER_STAGGER_MS
                    }
                    else -> {
                        val everyone = (manager.peers.map { it.userId } + me).filter { it != requester }.sorted()
                        everyone.indexOf(me).coerceAtLeast(0) * ANSWER_STAGGER_MS
                    }
                }
                val blobsArray = payload.optJSONArray("blobs")
                val blobs = (0 until (blobsArray?.length() ?: 0)).map { blobsArray!!.optString(it) }.toSet()
                later(delayMs) {
                    if (req !in answered) answerState(req, op.userId, blobs, session, engineFor)
                }
                null
            }
            "state_snapshot" -> {
                val req = payload.optString("req")
                remember(req)
                val to = payload.optString("to")
                val toMe = to.isEmpty() || to == "*" || to.equals(manager.currentUserId, ignoreCase = true)
                if ((req != pendingRequest && req !in sentRequests) || !toMe) return null
                // 只收第一位回覆者的段落：兩個人的分段方式不同，混在一起會湊出缺一塊的整份狀態。與 Apple 相同。
                val chosen = responderByRequest[req]
                if (chosen != null && chosen != op.userId) return null
                responderByRequest[req] = op.userId
                applySnapshotPart(payload, session, meta, canvas, engineFor, req = req)
            }
            // 分塊送來的大圖（見 `CollabBlobStream`）：只收給我的、我要過的那一份。與 Apple 相同。
            "state_blob" -> {
                val req = payload.optString("req")
                val to = payload.optString("to")
                val toMe = to == "*" || to.equals(manager.currentUserId, ignoreCase = true)
                if ((req != pendingRequest && req !in sentRequests) || !toMe) return null
                blobAssembler?.accept(payload)
                null
            }
            // 中繼寄存的整份狀態（只在補發時給剛進房的人；中繼不轉送）。以它自己的 `snap` 計段。
            "state_store" -> {
                // 房間裡有人在線：以他們回覆的整份狀態為準，不套用寄存的那一份（可能是舊版或過去的協作者
                // 只同步到一半時寄存的半份，帶較新的時戳，套了之後房主的完整內容反而蓋不過）。與 Apple 相同。
                if (manager.peers.isNotEmpty()) return null
                val snap = payload.optString("snap").ifEmpty { return null }
                applySnapshotPart(payload, session, meta, canvas, engineFor, storedSnap = snap)
            }
            else -> null
        }
    }

    private fun remember(req: String) {
        answered += req
        if (answered.size > 64) answered.remove(answered.first())
    }

    private val pendingInk = HashMap<String, Pair<JSONArray, Set<String>>>()

    private fun sessionPageIds(session: PadnoteSession): List<String> {
        val count = runCatching { session.pageCount().toInt() }.getOrDefault(0)
        return (0 until count).mapNotNull { runCatching { session.pageIdAt(it.toUInt()) }.getOrNull()?.let(AndroidCollabCanvas::canonicalPageId) }
    }

    private fun drainPendingInk(session: PadnoteSession, engineFor: (String) -> InkEngine?): Boolean {
        if (pendingInk.isEmpty()) return false
        val available = sessionPageIds(session).toSet()
        val readyPages = pendingInk.keys.filter { key -> available.any { it.equals(key, ignoreCase = true) } }
        if (readyPages.isEmpty()) return false
        var changed = false
        for (page in readyPages) {
            val pair = pendingInk.remove(page) ?: continue
            if (pair.first.length() > 0 && addStrokes(page, pair.first, session, engineFor)) {
                changed = true
            }
            if (pair.second.isNotEmpty() && removeStrokes(page, pair.second, session, engineFor)) {
                changed = true
            }
        }
        return changed
    }

    private fun addStrokes(
        rawPage: String, list: JSONArray, session: PadnoteSession, engineFor: (String) -> InkEngine?
    ): Boolean {
        val page = AndroidCollabCanvas.canonicalPageId(rawPage)
        val known = ink.known.getOrPut(page) { HashSet() }
        val now = System.currentTimeMillis()
        // （線上 id, 筆畫, 套件裡要用的 id）。用送出者的 id 寫進核心：同一筆在每一台的套件裡是同一個 id，
        // 檔案同步把送出者的筆畫檔帶過來時核心會去重（`materialize`），不會多出一份。
        val erased = tombstonesFor(page, session)
        val decoded = (0 until list.length()).mapNotNull { i ->
            val j = list.optJSONObject(i) ?: return@mapNotNull null
            CollabStroke.decode(j, now)?.let { (wire, s) -> Triple(wire, s, CollabStroke.coreId(j)) }
        }.filter { it.first !in known }
            // 擦掉過的筆畫永遠不放回來（I3）：較舊的整份狀態、補發的操作都可能還帶著它。
            .filter { (wire, _, core) ->
                wire.lowercase() !in erased && ink.localId(wire).lowercase() !in erased &&
                    (core == null || core.lowercase() !in erased)
            }
        if (decoded.isEmpty()) return false

        val currentSessionPages = sessionPageIds(session)
        if (currentSessionPages.none { it.equals(page, ignoreCase = true) }) {
            // 頁面尚未補上：若在預期頁序中則先擱著，等頁面建立後立即寫入（與 Apple holdCollabInkIfPending 一致）
            if (sync.desiredPageOrder().any { it.equals(page, ignoreCase = true) }) {
                val existing = pendingInk[page]
                val merged = JSONArray()
                existing?.first?.let { for (k in 0 until it.length()) merged.put(it.get(k)) }
                for (k in 0 until list.length()) merged.put(list.get(k))
                pendingInk[page] = merged to (existing?.second ?: emptySet())
                return true
            }
            return false
        }

        val engine = engineFor(page)
        if (engine != null) {
            val added = engine.applyRemoteStrokes(decoded.map { it.second }, decoded.map { it.third })
            decoded.zip(added).forEach { (d, s) -> s.coreStrokeId?.let { ink.remember(d.first, it) } }
            // 進了這個引擎的筆畫，之後被這台擦掉才送得出擦除。
            engineSeen[page]?.takeIf { it.first === engine }?.second?.addAll(decoded.map { it.first })
        } else {
            val existing = runCatching { session.visibleStrokeDetails(page) }.getOrDefault(emptyList())
                .map { it.id.lowercase() }.toHashSet()
            for ((wire, s, core) in decoded) {
                val local = core ?: UUID.randomUUID().toString()
                if (local !in existing) {
                    InkPackageWriter.add(session, page, local, s.tool, s.colorRgba, s.baseWidth, s.points,
                        s.layer.toUByte(), s.lineType.toUByte())
                }
                ink.remember(wire, local)
            }
        }
        known += decoded.map { it.first }
        ink.added(page, decoded.map { it.first })
        return true
    }

    private fun removeStrokes(rawPage: String, wires: Set<String>, session: PadnoteSession, engineFor: (String) -> InkEngine?): Boolean {
        val page = AndroidCollabCanvas.canonicalPageId(rawPage)
        recordTombstones(page, wires)
        val currentSessionPages = sessionPageIds(session)
        if (currentSessionPages.none { it.equals(page, ignoreCase = true) }) {
            if (sync.desiredPageOrder().any { it.equals(page, ignoreCase = true) }) {
                val existing = pendingInk[page]
                val mergedRemoved = (existing?.second ?: emptySet()) + wires
                pendingInk[page] = (existing?.first ?: JSONArray()) to mergedRemoved
                return true
            }
            return false
        }
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
        meta: NotebookMeta, canvas: () -> AndroidCollabCanvas,
        engineFor: ((String) -> InkEngine?)? = null
    ): Applied? {
        if (patches.isEmpty()) return null
        var view = canvas()
        var changed = false
        var pagesChanged = false
        val anchored = mutableListOf<Pair<String, List<*>>>()
        sync.isApplyingRemote = true
        var inkChanged = false
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
            if (engineFor != null && drainPendingInk(session, engineFor)) inkChanged = true
            for ((id, anchors) in anchored) resolveRunAnchors(id, anchors, view)
            sync.refreshShadow(view)
        } finally {
            sync.isApplyingRemote = false
        }
        return Applied(objects = true, pages = pagesChanged, ink = inkChanged)
    }

    /** 寫回之後的收尾：頁面、擱著的物件、堆疊順序。回傳（頁面變了的話）新的視角。 */
    private fun finishRemote(
        pagesChanged: Boolean, session: PadnoteSession, meta: NotebookMeta,
        view: AndroidCollabCanvas, canvas: () -> AndroidCollabCanvas
    ): AndroidCollabCanvas {
        val fresh = if (pagesChanged && reconcilePages(session, meta)) canvas() else view
        sync.retryDeferred(fresh)
        val (orders, under, locked) = sync.desiredStacking()
        fresh.writeStacking(orders, under, locked)
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
    /** 這一頁沒有任何筆畫、也沒有任何物件。 */
    private fun isEmptyPage(rawPageId: String, session: PadnoteSession): Boolean {
        val pageId = AndroidCollabCanvas.canonicalPageId(rawPageId)
        val strokes = runCatching { session.visibleStrokeDetails(pageId) }.getOrDefault(emptyList())
        if (strokes.isNotEmpty()) return false
        return sync.shadow.values.none {
            val p = (it["page"] as? String)?.let(AndroidCollabCanvas::canonicalPageId)
            p == pageId && it[ObjectPatch.DELETED] == false
        }
    }

    private fun reconcilePages(session: PadnoteSession, meta: NotebookMeta): Boolean {
        val desired = sync.desiredPageOrder().map(AndroidCollabCanvas::canonicalPageId)
        if (desired.isEmpty()) return false
        fun ids(): List<String> = sessionPageIds(session)
        meta.refresh(session)
        var current = ids()
        var changed = false
        val wanted = desired.toSet()

        // Step 1: 先補上缺少的頁面（補齊後 current.size > 1，後續才能安全刪除多餘的初始空白頁）
        for ((target, id) in desired.withIndex()) {
            if (current.any { it.equals(id, ignoreCase = true) }) continue
            val paper = (sync.shadow["page:$id"] ?: sync.shadow["page:${id.uppercase()}"])?.get("paper") as? String
            val style = paper?.let { p -> uniffi.padnote_core.paperTemplates().firstOrNull { it.id == p }?.pageStyle }
                ?: PageStyle.BLANK
            if (runCatching { session.addPageWithId(id, style) }.isFailure) continue
            val before = current.size
            val index = minOf(target, before)
            if (index < before) {
                runCatching { session.movePage(id, index.toUInt()) }
                // 插在中間：後面每一頁以頁碼記位置的東西往後讓一格（與本機插頁同一支）。
                meta.shiftPageKeyedData(session, index, before)
            }
            meta.insertPageTemplate(session, index, paper ?: meta.paperId(), before)
            current = ids()
            changed = true
        }

        // Step 2: 刪除不在 wanted 名單中的頁面（包括剛進房時預先建立的單頁空白頁）
        for (id in current.reversed()) {
            if (wanted.any { it.equals(id, ignoreCase = true) } || current.size <= 1) continue
            val index = current.indexOfFirst { it.equals(id, ignoreCase = true) }
            if (index < 0) continue
            if (runCatching { session.removePage(id) }.isFailure) continue
            meta.removePageTemplate(session, index, current.size)
            current = ids()
            changed = true
        }

        // Step 3: 依 desired 順序重新排列頁面
        for ((target, id) in desired.withIndex()) {
            val from = current.indexOfFirst { it.equals(id, ignoreCase = true) }
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
        // 圖檔之後在背景讀（以前在主執行緒逐張讀，圖一多畫面就卡、甚至 ANR）。
        val images = mutableListOf<Pair<String, JSONObject>>()
        for (entry in sync.snapshot()) {
            val json = entry.toJson()
            if (entry.type == "image") {
                val hash = entry.groups.values.firstNotNullOfOrNull { it["blob"] as? String }
                if (hash != null && hash !in blobs) images += hash to json
            }
            items += "objects" to json
        }
        // 筆跡：**每一頁的全部筆畫**都帶上（加上這次協同期間擦掉的）。
        //
        // 以前只帶「這次協同期間加入的」，假設之前就有的兩邊都有 —— 但剛加入的人往往還沒同步到
        // 房主最近寫的東西，只能等檔案同步（跨網路時要好幾秒、甚至整輪同步），看起來就是
        // 「開啟房主的筆記同步很慢」。收到的一方以筆畫 id 去重，已經有的不會多出一份。
        val pageIds = (0 until runCatching { session.pageCount().toInt() }.getOrDefault(0))
            .mapNotNull { runCatching { session.pageIdAt(it.toUInt()) }.getOrNull() }
        val pages = (pageIds + ink.sessionRemoved.keys).distinct()
        for (page in pages) {
            val strokes = JSONArray()
            // 引擎還沒讀完時它手上的不是整頁：改讀套件。
            val engine = engineFor(page)?.takeIf { it.hasLoaded }
            if (engine != null) {
                for (s in engine.strokes) {
                    val wire = s.coreStrokeId?.let { ink.wireId(it) } ?: continue
                    strokes.put(CollabStroke.encode(s, wire))
                }
            } else {
                for (s in runCatching { session.visibleStrokeDetails(page) }.getOrDefault(emptyList())) {
                    val wire = ink.wireId(s.id)
                    strokes.put(CollabStroke.encode(wire, s.tool, s.colorRgba, s.baseWidth, s.points, s.id))
                }
            }
            // 附上這一頁所有擦掉過的（這次協同的＋核心墓碑）：收到的一方若還留著其中幾筆，一併拿掉。
            val removed = (ink.sessionRemoved[page] ?: emptySet<String>()) + tombstonesFor(page, session)
            items += "ink" to JSONObject().put("page", page).put("strokes", strokes)
                .put("removed", JSONArray(removed.toList()))
        }
        val main = android.os.Handler(android.os.Looper.getMainLooper())
        Thread({
            // 小圖夾在整份狀態裡；大圖之後分塊送（見 `CollabBlobStream`）。
            val big = mutableListOf<String>()
            for ((hash, json) in images) {
                val bytes = runCatching { session.blobBytes(hash) }.getOrNull() ?: continue
                if (bytes.size > CollabBlobStream.INLINE_MAX) big += hash
                else json.put("b64", Base64.encodeToString(bytes, Base64.NO_WRAP))
            }
            main.post {
                sendStateParts(items, req, to)
                CollabBlobStream.stream(
                    big, req, to, PROTO,
                    read = { runCatching { session.blobBytes(it) }.getOrNull() },
                    queued = { manager.outgoingQueueBytes() },
                ) { payload ->
                    if (manager.status !is CollaborationManager.Status.Connected) return@stream false
                    main.post { manager.broadcastOplog("state_blob", payload) }
                    true
                }
            }
        }, "collab-answer").start()
    }

    /** 把回覆的整份狀態切段送出（每段約 [PART_BYTES]）。 */
    private fun sendStateParts(items: List<Pair<String, JSONObject>>, req: String, to: String) {
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
            val payload = JSONObject()
                .put("proto", PROTO).put("req", req).put("to", to)
                .put("part", index).put("parts", parts.size)
                .put("objects", part.first).put("ink", part.second)
            if (index == 0) {
                manager.broadcastOplog("state_snapshot", payload)
            } else {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    manager.broadcastOplog("state_snapshot", payload)
                }, index * 30L)
            }
        }
    }

    /**
     * 把這本目前的整份狀態寄存到雲端中繼（`state_store`，中繼不轉送，新加入的人補發時先拿到它）。
     * 內容與回覆 `state_request` 同一個格式、同樣端對端加密；信封上帶明文的 `snap`／`part`／`parts`／`seq`。
     * 不在畫面上的頁在背景讀核心（定期執行，不能卡主執行緒）。與 Apple `depositCollabState` 相同。
     */
    suspend fun depositState(session: PadnoteSession, engineFor: (String) -> InkEngine?) {
        if (!manager.isOnCloudRelay) return
        // 協作者沒完整同步過就不寄存：半份狀態寄存上去，之後每個加入者都只拿到半份。與 Apple 相同。
        if (!manager.isHost && !syncedOnce) return
        manager.noteStateDeposited()
        val objects = mutableListOf<JSONObject>()
        for (entry in sync.snapshot()) {
            val json = entry.toJson()
            // 圖片連位元組一起寄存：新加入的人手上沒有任何圖檔。
            if (entry.type == "image") {
                // 大圖不夾（雲端中繼一段放不下，夾了那一段被拒、整份寄存就收不齊）；之後由在線的人回覆時補。
                entry.groups.values.firstNotNullOfOrNull { it["blob"] as? String }?.let { hash ->
                    kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                        runCatching { session.blobBytes(hash) }.getOrNull()
                    }?.takeIf { it.size <= CollabBlobStream.DEPOSIT_INLINE_MAX }
                        ?.let { json.put("b64", Base64.encodeToString(it, Base64.NO_WRAP)) }
                }
            }
            objects += json
        }
        val pageIds = (0 until runCatching { session.pageCount().toInt() }.getOrDefault(0))
            .mapNotNull { runCatching { session.pageIdAt(it.toUInt()) }.getOrNull() }
        val pages = (pageIds + ink.sessionRemoved.keys).distinct()
        val inkItems = mutableListOf<JSONObject>()
        for (page in pages) {
            val strokes = JSONArray()
            val engine = engineFor(page)?.takeIf { it.hasLoaded }
            if (engine != null) {
                for (s in engine.strokes) {
                    val wire = s.coreStrokeId?.let { ink.wireId(it) } ?: continue
                    strokes.put(CollabStroke.encode(s, wire))
                }
            } else {
                val details = kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) {
                    runCatching { session.visibleStrokeDetails(page) }.getOrDefault(emptyList())
                }
                for (s in details) {
                    strokes.put(CollabStroke.encode(ink.wireId(s.id), s.tool, s.colorRgba, s.baseWidth, s.points, s.id))
                }
            }
            val removed = (ink.sessionRemoved[page] ?: emptySet<String>()) + tombstonesFor(page, session)
            if (strokes.length() == 0 && removed.isEmpty()) continue
            inkItems += JSONObject().put("page", page).put("strokes", strokes).put("removed", JSONArray(removed.toList()))
        }
        if (manager.status !is CollaborationManager.Status.Connected) return
        val parts = mutableListOf<Pair<JSONArray, JSONArray>>()
        var objPart = JSONArray()
        var inkPart = JSONArray()
        var size = 0
        for ((isInk, json) in objects.map { false to it } + inkItems.map { true to it }) {
            val length = json.toString().length
            if (size > 0 && size + length > PART_BYTES) {
                parts += objPart to inkPart
                objPart = JSONArray(); inkPart = JSONArray(); size = 0
            }
            if (isInk) inkPart.put(json) else objPart.put(json)
            size += length
        }
        parts += objPart to inkPart
        if (parts.size > STORE_PARTS_MAX) {
            // 整本超過雲端中繼的寄存上限，送了也存不下。每個房間只提醒一次；原本寄存的那一份照舊留著。與 Apple 相同。
            if (warnedTooLarge != manager.roomId) {
                warnedTooLarge = manager.roomId
                manager.relayNotices.tryEmit(com.kairumo.padnote.L10n.t("relay_notice_store_too_large"))
            }
            return
        }
        val snap = UUID.randomUUID().toString().lowercase()
        val seq = manager.relaySeq
        for ((index, part) in parts.withIndex()) {
            val payload = JSONObject().put("proto", PROTO).put("req", "store").put("to", "*").put("snap", snap)
                .put("part", index).put("parts", parts.size)
                .put("objects", part.first).put("ink", part.second)
            val envelope = mapOf("snap" to snap, "part" to index, "parts" to parts.size, "seq" to seq)
            if (index == 0) {
                manager.broadcastOplog("state_store", payload, envelope = envelope)
            } else {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    manager.broadcastOplog("state_store", payload, envelope = envelope)
                }, index * 30L)
            }
        }
    }

    /**
     * 收到整份狀態的一段。全部收齊後，把「只有自己有」的物件交給下一次送出補給房間。
     * @param storedSnap 中繼寄存的那一份（`state_store`）的 id：與自己發出的請求分開計段。
     */
    private fun applySnapshotPart(
        payload: JSONObject, session: PadnoteSession, meta: NotebookMeta,
        canvas: () -> AndroidCollabCanvas, engineFor: (String) -> InkEngine?, storedSnap: String? = null,
        req: String = ""
    ): Applied? {
        val part = payload.optInt("part", -1)
        val parts = payload.optInt("parts", 1)
        if (storedSnap != null && storedSnap != this.storedSnap) {
            this.storedSnap = storedSnap
            storedParts = HashSet()
        }
        val received = if (storedSnap != null) storedParts else partsByRequest.getOrPut(req) { HashSet() }
        if (part < 0 || !received.add(part)) return null
        val list = payload.optJSONArray("objects") ?: JSONArray()
        val entries = (0 until list.length()).mapNotNull { i ->
            val json = list.optJSONObject(i) ?: return@mapNotNull null
            json.optString("b64").takeIf { it.isNotEmpty() }?.let { b64 ->
                runCatching { session.putBlob(Base64.decode(b64, Base64.DEFAULT)) }
            }
            SnapshotEntry.fromJson(json)
        }
        roomKeys.addAll(entries.map { "${it.type}:${it.id}" })
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
                val removed = pageInk.optJSONArray("removed")
                val wires = (0 until (removed?.length() ?: 0)).map { removed!!.optString(it) }.toSet()
                // 先記墓碑再放筆畫：同一份狀態裡既有、又標成擦掉的那幾筆不會先被放回來。
                recordTombstones(page, wires)
                pageInk.optJSONArray("strokes")?.let {
                    if (addStrokes(page, it, session, engineFor)) {
                        com.kairumo.padnote.canvas.ThumbnailFreshness.markDirty(page)
                        inkChanged = true
                    }
                }
                if (wires.isNotEmpty() && removeStrokes(page, wires, session, engineFor)) {
                    com.kairumo.padnote.canvas.ThumbnailFreshness.markDirty(page)
                    inkChanged = true
                }
            }
            if (drainPendingInk(session, engineFor)) inkChanged = true
            sync.refreshShadow(view)
        } finally {
            sync.isApplyingRemote = false
        }
        var needsPublish = false
        if (received.size >= parts) {
            if (storedSnap == null) {
                partsByRequest.remove(req)
                responderByRequest.remove(req)
                if (pendingRequest == req) pendingRequest = null
                // 只有回覆這台請求的那一份算「完整同步過」：寄存的那一份可能比較舊。與 Apple 相同。
                syncedOnce = true
            }
            // 只有自己有的物件（例如離線時新增的）：忘掉它們，下一次送出就會當成新的補給房間。
            //
            // **空白頁例外**：掃碼加入時本機沒有這本，會先建一本只有一頁空白頁的筆記（頁面 id 是本機算的，
            // 與房主的不同）。以前它也被當成「只有自己有」補給房間 —— 每個人那邊都多出一頁空白頁。
            // 沒有任何筆畫與物件的頁：本機刪掉、不送出。有內容的照舊補給房間。
            // 「房間裡有的」以兩份整份狀態的聯集判斷：寄存的那一份可能比較舊，只拿它比，房主之後才加的
            // 物件與空白頁會被當成「只有自己有」—— 物件以舊值再送一次、空白頁被刪掉。與 Apple 相同。
            val roomKeys = this.roomKeys.map {
                if (it.startsWith("page:")) "page:${AndroidCollabCanvas.canonicalPageId(it.removePrefix("page:"))}" else it
            }.toSet()
            val localOnly = sync.liveKeys.filter { key ->
                val canonicalKey = if (key.startsWith("page:")) "page:${AndroidCollabCanvas.canonicalPageId(key.removePrefix("page:"))}" else key
                canonicalKey !in roomKeys && !key.startsWith("meta:")
            }
            // 還有擱著的筆畫等著寫進去的頁不是空白頁（那是房間的頁，只是筆畫還沒落地）。
            val emptyPages = localOnly.filter { key ->
                if (!key.startsWith("page:")) return@filter false
                val pageId = key.removePrefix("page:")
                if (pendingInk.keys.any { it.equals(pageId, ignoreCase = true) }) return@filter false
                isEmptyPage(pageId, session)
            }
            for (key in emptyPages) sync.shadow[key] = mutableMapOf(ObjectPatch.DELETED to true)
            if (emptyPages.isNotEmpty() && reconcilePages(session, meta)) pagesChanged = true
            val keep = localOnly - emptyPages.toSet()
            sync.forget(keep)
            needsPublish = keep.isNotEmpty()
            if (drainPendingInk(session, engineFor)) inkChanged = true
        }
        return Applied(objects = true, pages = pagesChanged, ink = inkChanged, needsPublish = needsPublish)
    }

    private companion object {
        const val PROTO = 4
        /** 雲端中繼寄存一份整份狀態最多幾段（與 `deploy/relay-cloudflare` 的 `STORE_PARTS_MAX` 相同）。 */
        const val STORE_PARTS_MAX = 256
        /** 新圖片的位元組（base64），只在建立時帶（與 Apple 端 `CollabObjectSync.blobField` 相同）。 */
        const val BLOB_FIELD = "#blob"
        /** 逐字格式的錨點（與 Apple 端 `CollabObjectSync.anchorField` 相同）。 */
        const val ANCHOR_FIELD = "#ra"
        /** 整份狀態每段的大約上限（字元數）。 */
        const val PART_BYTES = 400_000
        /** 回覆整份狀態時，排名每多一位多等的時間。 */
        const val ANSWER_STAGGER_MS = 700L
        /** 房主在線時，協作者多等這麼久才補回（房主的回覆通常已經到了）。與 Apple `hostGrace` 相同。 */
        const val HOST_GRACE_MS = 3_000L
    }
}
