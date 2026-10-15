package com.kairumo.padnote.collab

import org.json.JSONArray
import org.json.JSONObject

/**
 * 即時協同的物件合併（欄位層級「最後寫入者勝」）。與 Apple 端 `CollabObjectSync` 逐行對應。
 *
 * 每一條規則都**可交換、可結合、冪等**：同一組操作不論以什麼順序、重複幾次套用，結果都相同。
 * 欄位是兩平台共用的套件格式（設計 §8.2），由 [CollabCanvas] 從 Android 的物件讀出、寫回。
 */

/** 一個物件在線上格式裡的樣子。 */
data class CollabEntry(val type: String, val id: String, val dict: Map<String, Any>)

/** Android 這一邊的筆記本：把物件編成線上欄位、把合併結果寫回去。 */
interface CollabCanvas {
    /** 頁面 id，依目前順序。 */
    val pageIds: List<String>

    /**
     * 這次要比對的物件（`type:id` → 欄位）。頁面與頁面設定也在裡面。
     *
     * 每個物件帶 `under`（是否在筆跡下方），在堆疊順序裡的帶 `z`（取自 [zPositions]，設計 §8.7）。
     */
    fun maps(pagePositions: Map<String, String>, zPositions: Map<String, String>, allPages: Boolean): Map<String, CollabEntry>

    /** 每一頁的堆疊順序（由後到前，正規 id）。只列使用者排過的物件 —— 沒排過的照預設畫法。 */
    fun objectOrders(): Map<String, List<String>>

    /** 寫回合併後的堆疊順序與「在筆跡下方」名單（頁面 id → 正規 id）。 */
    fun writeStacking(orders: Map<String, List<String>>, under: Map<String, List<String>>)

    /** 這一筆 shadow 裡的物件是不是「這次比對的範圍內」—— 範圍外的不見了不代表被刪除。 */
    fun inScope(type: String, dict: Map<String, Any>): Boolean

    /** 寫回一個物件。回傳 false = 它所在的頁還不存在，晚點再試。 */
    fun write(type: String, id: String, fields: Map<String, Any>, deleted: Boolean): Boolean
}

/** 整份狀態裡的一個物件：欄位依寫入時戳分組（設計 §7）。 */
data class SnapshotEntry(val type: String, val id: String, val groups: Map<LamportStamp, Map<String, Any>>) {
    fun toJson(): JSONObject = JSONObject().put("type", type).put("id", id).put("g", JSONArray().also { array ->
        for ((stamp, fields) in groups) {
            array.put(JSONObject().put("l", stamp.lamport).put("u", stamp.user).put("f", CollabJson.toJsonObject(fields)))
        }
    })

    companion object {
        fun fromJson(obj: JSONObject): SnapshotEntry? {
            val type = obj.optString("type").ifEmpty { return null }
            val id = obj.optString("id").ifEmpty { return null }
            val list = obj.optJSONArray("g") ?: return null
            val groups = LinkedHashMap<LamportStamp, Map<String, Any>>()
            for (i in 0 until list.length()) {
                val g = list.optJSONObject(i) ?: continue
                val fields = g.optJSONObject("f") ?: continue
                groups[LamportStamp(g.optLong("l"), g.optString("u"))] = CollabJson.fromJsonObject(fields)
            }
            return SnapshotEntry(type, id, groups)
        }
    }
}

data class SnapshotResult(val changed: Boolean, val textOverrides: List<Pair<String, String>>)

/** 一次本機修改要送出的東西。 */
data class CollabOutgoing(
    val patches: List<ObjectPatch>,
    /** 文字方塊內容的變動：`(方塊 id, 舊文字, 新文字)`。內容走字元 CRDT（設計 §8.3）。 */
    val textEdits: List<Triple<String, String, String>>
) {
    val isEmpty: Boolean get() = patches.isEmpty() && textEdits.isEmpty()
}

class CollabObjectSync {

    val shadow = HashMap<String, MutableMap<String, Any>>()
    private val stamps = HashMap<String, MutableMap<String, LamportStamp>>()
    val pagePositions = HashMap<String, String>()
    /** 物件 id → 堆疊順序的排序鍵（設計 §8.7）。與頁面的排序鍵同一套分數索引。 */
    val zPositions = HashMap<String, String>()
    val deferredKeys = HashSet<String>()
    /** 正在套用別人的修改：這段期間的寫回不送出。 */
    var isApplyingRemote = false
    /** 本機編碼器產生過的欄位（依型別）。理由見 Apple 端同名欄位的說明：分辨「清掉」與「另一個平台才有」。 */
    private val localKeys = HashMap<String, MutableSet<String>>()

    private fun learn(maps: Map<String, CollabEntry>) {
        for (entry in maps.values) localKeys.getOrPut(entry.type) { HashSet() }.addAll(entry.dict.keys)
    }

    private fun isLocalKey(field: String, type: String) = localKeys[type]?.contains(field) == true

    /** 以這份內容為「大家都有的」起點。不送出任何東西。 */
    fun reset(canvas: CollabCanvas) {
        shadow.clear(); stamps.clear(); deferredKeys.clear(); pagePositions.clear(); zPositions.clear()
        val ids = canvas.pageIds
        ids.zip(FractionalIndex.initialKeys(ids.size)).forEach { (id, key) -> pagePositions[id] = key }
        // 同樣的順序算出同樣的鍵：兩台以同一份筆記開始時，每個物件的排序鍵也相同。
        for (order in canvas.objectOrders().values) {
            order.zip(FractionalIndex.initialKeys(order.size)).forEach { (id, key) -> zPositions[id] = key }
        }
        val maps = canvas.maps(pagePositions, zPositions, allPages = true)
        learn(maps)
        for ((key, entry) in maps) shadow[key] = entry.dict.toMutableMap().also { it[ObjectPatch.DELETED] = false }
    }

    fun outgoing(canvas: CollabCanvas, stamp: LamportStamp): CollabOutgoing {
        reconcilePagePositions(canvas.pageIds)
        reconcileZ(canvas.objectOrders())
        val patches = mutableListOf<ObjectPatch>()
        val textEdits = mutableListOf<Triple<String, String, String>>()
        val current = canvas.maps(pagePositions, zPositions, allPages = false)
        learn(current)
        for ((key, entry) in current) {
            val known = shadow[key] ?: emptyMap()
            val isNew = known[ObjectPatch.DELETED] != false
            val changed = LinkedHashMap<String, Any>()
            if (isNew) changed[ObjectPatch.DELETED] = false
            val createOnly = CREATE_ONLY[entry.type] ?: emptySet()
            for ((field, value) in entry.dict) {
                if (equal(known[field], value)) continue
                if (!isNew && field in createOnly) {
                    if (entry.type == "text" && field == "text") {
                        textEdits += Triple(entry.id, (known[field] as? String) ?: "", value as? String ?: "")
                    }
                    shadow.getOrPut(key) { HashMap() }[field] = value
                    continue
                }
                changed[field] = value
            }
            for (field in known.keys) {
                if (field != ObjectPatch.DELETED && field !in entry.dict && isLocalKey(field, entry.type)) {
                    changed[field] = JsonNull
                }
            }
            if (changed.isNotEmpty()) patches += ObjectPatch(entry.type, entry.id, changed)
        }
        for ((key, known) in shadow) {
            // 還在等頁面（或兩端形狀）的物件本機本來就還沒有：不是被刪除。
            if (key in current || known[ObjectPatch.DELETED] != false || key in deferredKeys) continue
            val type = key.substringBefore(':')
            val id = key.substringAfter(':')
            if (type == "meta" || !canvas.inScope(type, known)) continue
            patches += ObjectPatch(type, id, mapOf(ObjectPatch.DELETED to true))
        }
        patches.forEach { merge(it, stamp) }
        return CollabOutgoing(patches, textEdits)
    }

    /** 本機頁序變了：只替順序對不上的頁換排序鍵（與 Apple 端相同）。 */
    private fun reconcilePagePositions(order: List<String>) = reconcileKeys(order, pagePositions)

    /** 本機的堆疊順序變了：同樣只替順序對不上的物件換鍵；不在任何順序裡的物件拿掉它的鍵。 */
    private fun reconcileZ(orders: Map<String, List<String>>) {
        val listed = HashSet<String>()
        for (order in orders.values) {
            reconcileKeys(order, zPositions)
            listed += order
        }
        zPositions.keys.retainAll(listed)
    }

    /** 依合併狀態算出每一頁的堆疊順序與「在筆跡下方」名單（已刪除的不算）。 */
    fun desiredStacking(): Pair<Map<String, List<String>>, Map<String, List<String>>> {
        val ordered = HashMap<String, MutableList<Pair<String, String>>>()
        val under = HashMap<String, MutableList<String>>()
        for ((key, dict) in shadow) {
            if (dict[ObjectPatch.DELETED] != false) continue
            val page = dict["page"] as? String ?: continue
            val id = key.substringAfter(':')
            (dict["z"] as? String)?.let { ordered.getOrPut(page) { mutableListOf() } += it to id }
            if (dict["under"] == true) under.getOrPut(page) { mutableListOf() } += id
        }
        return ordered.mapValues { (_, list) -> list.sortedWith(compareBy({ it.first }, { it.second })).map { it.second } } to
            under.mapValues { (_, list) -> list.sorted() }
    }

    fun apply(patch: ObjectPatch, stamp: LamportStamp, canvas: CollabCanvas): Boolean {
        val exists = shadow[patch.key]?.get(ObjectPatch.DELETED) == false
        val fields = if (exists) patch.fields - (CREATE_ONLY[patch.type] ?: emptySet()) else patch.fields
        if (!merge(ObjectPatch(patch.type, patch.id, fields), stamp)) return false
        if (patch.type == "page") (shadow[patch.key]?.get("pos") as? String)?.let { pagePositions[patch.id] = it }
        if ("z" in fields) {
            val z = shadow[patch.key]?.get("z") as? String
            if (z != null) zPositions[patch.id] = z else zPositions.remove(patch.id)
        }
        writeBack(patch.key, patch.type, patch.id, canvas)
        return true
    }

    // ── 整份狀態（設計 §7：加入房間、補發不完整）──

    /** 合併狀態的完整內容：每個物件依時戳分組的欄位（含已刪除的墓碑）。 */
    fun snapshot(): List<SnapshotEntry> = shadow.map { (key, dict) ->
        val fieldStamps = stamps[key] ?: emptyMap<String, LamportStamp>()
        val groups = LinkedHashMap<LamportStamp, MutableMap<String, Any>>()
        for ((field, value) in dict) groups.getOrPut(fieldStamps[field] ?: LamportStamp.ZERO) { LinkedHashMap() }[field] = value
        SnapshotEntry(key.substringBefore(':'), key.substringAfter(':'), groups)
    }

    /**
     * 套用別人給的整份狀態（只有要狀態的那一方套用）。
     *
     * 沒有時戳的欄位以 [LamportStamp.ROOM_BASE] 寫入：房間裡的內容優先於自己可能過期的起點，
     * 但輸給任何一次真正的修改。兩邊都有、內容不同的文字方塊回傳在 `textOverrides` ——
     * 文字內容走字元 CRDT，要由呼叫端以房間的全文為新基準重建（設計 §8.3 的退路）。
     */
    fun applySnapshot(entries: List<SnapshotEntry>, canvas: CollabCanvas): SnapshotResult {
        val overrides = mutableListOf<Pair<String, String>>()
        var changed = false
        for (entry in entries) {
            val key = "${entry.type}:${entry.id}"
            for ((stamp, fields) in entry.groups) {
                val effective = if (stamp.lamport == 0L) LamportStamp.ROOM_BASE else stamp
                if (apply(ObjectPatch(entry.type, entry.id, fields), effective, canvas)) changed = true
            }
            if (entry.type == "text") {
                val theirs = entry.groups.values.firstNotNullOfOrNull { it["text"] as? String }
                val mine = shadow[key]?.get("text") as? String
                if (theirs != null && mine != null && theirs != mine && shadow[key]?.get(ObjectPatch.DELETED) == false) {
                    overrides += entry.id to theirs
                }
            }
        }
        return SnapshotResult(changed, overrides)
    }

    /** 合併狀態裡還在的物件（`type:id`）。 */
    val liveKeys: Set<String> get() = shadow.filterValues { it[ObjectPatch.DELETED] == false }.keys

    /**
     * 忘掉這些物件：下一次送出會把它們當成新的整個送出去。
     * 加入房間時「只有自己有」的物件以此補給房間（設計 §7）。
     */
    fun forget(keys: Collection<String>) {
        for (key in keys) {
            shadow.remove(key); stamps.remove(key); deferredKeys.remove(key)
        }
    }

    private fun merge(patch: ObjectPatch, stamp: LamportStamp): Boolean {
        val dict = shadow.getOrPut(patch.key) { HashMap() }
        val fieldStamps = stamps.getOrPut(patch.key) { HashMap() }
        var accepted = false
        for ((field, value) in patch.fields) {
            val current = fieldStamps[field] ?: LamportStamp.ZERO
            if (current >= stamp) continue
            fieldStamps[field] = stamp
            if (value == JsonNull) dict.remove(field) else dict[field] = value
            accepted = true
        }
        return accepted
    }

    private fun writeBack(key: String, type: String, id: String, canvas: CollabCanvas) {
        val dict = shadow[key] ?: return
        val deleted = dict[ObjectPatch.DELETED] == true
        if (canvas.write(type, id, dict, deleted)) deferredKeys.remove(key) else deferredKeys.add(key)
    }

    fun retryDeferred(canvas: CollabCanvas) {
        for (key in deferredKeys.toList()) writeBack(key, key.substringBefore(':'), key.substringAfter(':'), canvas)
    }

    fun desiredPageOrder(): List<String> =
        shadow.entries.mapNotNull { (key, dict) ->
            if (!key.startsWith("page:") || dict[ObjectPatch.DELETED] == true) return@mapNotNull null
            val pos = dict["pos"] as? String ?: return@mapNotNull null
            key.removePrefix("page:") to pos
        }.sortedWith(compareBy({ it.second }, { it.first })).map { it.first }

    /** 寫回之後以實際的編碼更新 shadow（時戳不動）。另一個平台才有的欄位保留。 */
    fun refreshShadow(canvas: CollabCanvas) {
        val current = canvas.maps(pagePositions, zPositions, allPages = false)
        for ((key, entry) in current) {
            val dict = shadow.getOrPut(key) { HashMap() }
            dict.putAll(entry.dict)
            dict.keys.filter { it != ObjectPatch.DELETED && it !in entry.dict && isLocalKey(it, entry.type) }
                .forEach { dict.remove(it) }
            dict[ObjectPatch.DELETED] = false
        }
        for ((key, known) in shadow) {
            if (key in current || known[ObjectPatch.DELETED] != false || key.startsWith("meta:") || key in deferredKeys) continue
            if (!canvas.inScope(key.substringBefore(':'), known)) continue
            known[ObjectPatch.DELETED] = true
        }
    }

    companion object {
        /** 依本機的順序補排序鍵：順序對的沿用，對不上的在前後兩個鍵之間取一個新的。 */
        fun reconcileKeys(order: List<String>, keys: MutableMap<String, String>) {
            var previous = ""
            for ((index, id) in order.withIndex()) {
                val key = keys[id]
                if (key != null && key > previous) {
                    previous = key
                    continue
                }
                val upper = order.drop(index + 1).asSequence().mapNotNull { keys[it] }.firstOrNull { it > previous }
                val fresh = FractionalIndex.between(previous, upper)
                keys[id] = fresh
                previous = fresh
            }
        }

        /** 只在新增時有效的欄位：文字方塊的內容之後走字元 CRDT。 */
        val CREATE_ONLY: Map<String, Set<String>> = mapOf("text" to setOf("text"))

        fun equal(a: Any?, b: Any?): Boolean = when {
            a == null && b == null -> true
            a == null || b == null -> false
            a is Number && b is Number -> a.toDouble() == b.toDouble()
            else -> a == b
        }
    }
}

/** 每個文字方塊一份 [CollabText]（設計 §8.3）。 */
class CollabTextHub {
    private val replicas = HashMap<String, CollabText>()

    fun replica(id: String, base: String, site: String): CollabText =
        replicas.getOrPut(id) { CollabText(base, site) }

    fun existing(id: String): CollabText? = replicas[id]

    fun rebase(id: String, text: String, site: String) {
        replicas[id] = CollabText(text, site)
    }

    fun reset() = replicas.clear()
}

/** 每一頁已經同步過的筆畫，以及線上 id ↔ 本機筆畫 id 的對應。 */
class CollabInkLedger {
    val known = HashMap<String, MutableSet<String>>()
    private val wireForLocal = HashMap<String, String>()
    private val localForWire = HashMap<String, String>()

    fun wireId(local: String): String = wireForLocal[local] ?: local
    fun localId(wire: String): String = localForWire[wire] ?: wire

    fun remember(wire: String, local: String) {
        wireForLocal[local] = wire
        localForWire[wire] = local
    }

    /** 這次協同期間加入的筆畫（頁面 → 線上 id）。整份狀態只帶這些 —— 之前就有的兩邊都有。 */
    val sessionAdded = HashMap<String, MutableSet<String>>()
    /** 這次協同期間擦掉的筆畫。 */
    val sessionRemoved = HashMap<String, MutableSet<String>>()

    fun added(page: String, wires: Collection<String>) {
        sessionAdded.getOrPut(page) { HashSet() } += wires
        sessionRemoved[page]?.removeAll(wires.toSet())
    }

    fun removed(page: String, wires: Collection<String>) {
        sessionRemoved.getOrPut(page) { HashSet() } += wires
        sessionAdded[page]?.removeAll(wires.toSet())
    }

    fun reset() {
        known.clear(); wireForLocal.clear(); localForWire.clear(); sessionAdded.clear(); sessionRemoved.clear()
    }
}
