package com.kairumo.padnote.collab

import org.json.JSONArray
import org.json.JSONObject
import java.security.MessageDigest

/**
 * 即時協同協定 3 的共用積木（設計見 `docs/plans/realtime-collaboration.md` §8）。
 *
 * 每一個演算法都與 Apple 端 `CollabProtocol.swift` **逐行對應**，兩邊用同一組測試向量驗證 ——
 * 算法有一點點不同，兩台就會算出不同的字序、不同的頁序，而那種不一致不會報錯，
 * 只會讓兩個人看到不同的筆記。
 */

/** 操作的時戳：Lamport 時鐘 + 使用者 id。全序：先比時鐘，相同再比 id。 */
data class LamportStamp(val lamport: Long, val user: String) : Comparable<LamportStamp> {
    override fun compareTo(other: LamportStamp): Int =
        if (lamport != other.lamport) lamport.compareTo(other.lamport) else user.compareTo(other.user)

    companion object {
        val ZERO = LamportStamp(0, "")
        /**
         * 整份狀態裡「沒有時戳」（加入房間時就有）的欄位，在要狀態的一方以這個時戳寫入：
         * 勝過自己的起點（[ZERO]），輸給任何一次真正的修改 —— 房間裡的內容優先於剛加入者
         * 可能過期的那一份（設計 §7）。
         */
        val ROOM_BASE = LamportStamp(0, "~base")
    }
}

/** 欄位被清掉（JSON null）的標記。Kotlin 的 null 在 Map 裡分不出「沒有」與「清掉」。 */
object JsonNull {
    override fun toString() = "null"
}

/** 一個物件（或頁面、頁面層級設定）的欄位修改。 */
data class ObjectPatch(val type: String, val id: String, val fields: Map<String, Any>) {
    val key: String get() = "$type:$id"

    fun toJson(): JSONObject = JSONObject()
        .put("type", type).put("id", id).put("fields", CollabJson.toJsonObject(fields))

    companion object {
        const val DELETED = "#deleted"

        fun fromJson(obj: JSONObject): ObjectPatch? {
            val type = obj.optString("type").ifEmpty { return null }
            val id = obj.optString("id").ifEmpty { return null }
            val fields = obj.optJSONObject("fields") ?: return null
            return ObjectPatch(type, id, CollabJson.fromJsonObject(fields))
        }
    }
}

// ── 文字 CRDT（RGA）────────────────────────────────────────────

/**
 * 一個文字方塊的字元層級 CRDT（設計 §8.3）。與 Apple 端 `CollabText` 相同。
 *
 * 每個字（UTF-16 碼元）有全域唯一的 id `"<n>@<site>"`；插入是「插在某個 id 之後」，刪除只做墓碑。
 */
class CollabText(base: String, val site: String) {

    data class Op(val kind: Char, val id: String, val after: String = "", val unit: Char = '\u0000') {
        fun toJson(): JSONObject = if (kind == 'i') {
            JSONObject().put("o", "i").put("id", id).put("after", after).put("c", unit.toString())
        } else {
            JSONObject().put("o", "d").put("id", id)
        }

        companion object {
            fun insert(id: String, after: String, unit: Char) = Op('i', id, after, unit)
            fun delete(id: String) = Op('d', id)

            fun fromJson(obj: JSONObject): Op? {
                val id = obj.optString("id").ifEmpty { return null }
                return when (obj.optString("o")) {
                    "i" -> {
                        val c = obj.optString("c")
                        if (c.isEmpty()) null else Op('i', id, obj.optString("after"), c[0])
                    }
                    "d" -> Op('d', id)
                    else -> null
                }
            }
        }
    }

    private class Element(val id: String, val unit: Char, var deleted: Boolean)

    val baseHash: String = hash(base)
    private val elements = base.mapIndexed { i, c -> Element("0@#$i", c, false) }.toMutableList()
    private val positions = HashMap<String, Int>()
    private var counter = 0
    private val pending = mutableListOf<Op>()

    init { reindex() }

    val text: String get() = buildString { elements.forEach { if (!it.deleted) append(it.unit) } }
    val hasPending: Boolean get() = pending.isNotEmpty()

    /** 本機的文字從 [old] 變成 [new]：產生對應的操作（並已套用到自己身上）。 */
    fun localEdit(old: String, new: String): List<Op> {
        var prefix = 0
        while (prefix < old.length && prefix < new.length && old[prefix] == new[prefix]) prefix++
        var suffix = 0
        while (suffix < old.length - prefix && suffix < new.length - prefix &&
            old[old.length - 1 - suffix] == new[new.length - 1 - suffix]) suffix++

        val visible = visibleIds()
        val ops = mutableListOf<Op>()
        val deleteEnd = maxOf(prefix, minOf(visible.size, old.length - suffix))
        for (i in prefix until deleteEnd) ops += Op.delete(visible[i])
        var anchor = if (prefix > 0 && prefix - 1 < visible.size) visible[prefix - 1] else ""
        for (i in prefix until new.length - suffix) {
            counter++
            val id = "$counter@$site"
            ops += Op.insert(id, anchor, new[i])
            anchor = id
        }
        ops.forEach { apply(it) }
        return ops
    }

    /** 套用一個操作。錨點還沒出現的先暫存，之後自動補上。 */
    fun apply(op: Op): Boolean {
        if (!applyOne(op)) {
            if (op !in pending) pending += op
            return false
        }
        var progressed = true
        while (progressed) {
            progressed = false
            val index = pending.indexOfFirst { applyOne(it) }
            if (index >= 0) {
                pending.removeAt(index)
                progressed = true
            }
        }
        return true
    }

    private fun applyOne(op: Op): Boolean {
        if (op.kind == 'd') {
            val index = positions[op.id] ?: return false
            elements[index].deleted = true
            return true
        }
        if (positions.containsKey(op.id)) return true
        var index = if (op.after.isEmpty()) 0 else (positions[op.after] ?: return false) + 1
        while (index < elements.size && precedes(elements[index].id, op.id)) index++
        elements.add(index, Element(op.id, op.unit, false))
        counterOf(op.id)?.let { counter = maxOf(counter, it) }
        reindex()
        return true
    }

    private fun visibleIds() = elements.filter { !it.deleted }.map { it.id }

    /** 目前第 [index] 個看得見的字的 id（格式錨點用，設計 §8.3）。 */
    fun idAt(index: Int): String? = visibleIds().getOrNull(index)

    /**
     * 某個 id 現在是第幾個看得見的字。那個字被刪了：[forward] 取它後面第一個看得見的字，
     * 否則取前面那一個。不認得這個 id（操作還沒到）回 `null`。
     */
    fun visibleIndexOf(id: String, forward: Boolean): Int? {
        val position = positions[id] ?: return null
        var before = 0
        for (i in 0 until position) if (!elements[i].deleted) before++
        if (!elements[position].deleted) return before
        if (forward) {
            for (i in position + 1 until elements.size) if (!elements[i].deleted) return before
            return null
        }
        return if (before > 0) before - 1 else null
    }

    private fun reindex() {
        positions.clear()
        elements.forEachIndexed { i, e -> positions[e.id] = i }
    }

    companion object {
        fun hash(text: String): String =
            MessageDigest.getInstance("SHA-256").digest(text.toByteArray(Charsets.UTF_8))
                .take(8).joinToString("") { "%02x".format(it) }

        /** `a` 排在 `b` 前面（較新）：先比計數，相同再比 site。 */
        fun precedes(a: String, b: String): Boolean {
            val ca = counterOf(a) ?: 0
            val cb = counterOf(b) ?: 0
            if (ca != cb) return ca > cb
            return siteOf(a) > siteOf(b)
        }

        fun counterOf(id: String): Int? = id.substringBefore('@', "").toIntOrNull()
        fun siteOf(id: String): String = id.substringAfter('@', "")
    }
}

// ── 分數索引（頁面順序）──────────────────────────────────────────

/** 字典序排序鍵（設計 §8.4）。演算法與 Apple 端 `FractionalIndex` 相同。 */
object FractionalIndex {
    const val DIGITS = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    fun between(a: String, b: String?): String = midpoint(a, b)

    private fun midpoint(a: String, b: String?): String {
        if (b != null) {
            var n = 0
            while (n < b.length && (if (n < a.length) a[n] else '0') == b[n]) n++
            if (n > 0) return b.substring(0, n) + midpoint(a.drop(n), b.drop(n))
        }
        val digitA = if (a.isNotEmpty()) DIGITS.indexOf(a[0]) else 0
        val digitB = if (b != null && b.isNotEmpty()) DIGITS.indexOf(b[0]) else DIGITS.length
        if (digitB - digitA > 1) return DIGITS[(digitA + digitB + 1) / 2].toString()
        if (b != null && b.length > 1) return b.substring(0, 1)
        return DIGITS[digitA] + midpoint(a.drop(1), null)
    }

    fun initialKeys(count: Int): List<String> {
        val keys = mutableListOf<String>()
        var last = ""
        repeat(count) {
            last = between(last, null)
            keys += last
        }
        return keys
    }
}

// ── JSON ───────────────────────────────────────────────────────

/**
 * 外觀 JSON 攤平成「點號路徑 → 值」，以及 JSON ↔ Kotlin 值的轉換。
 *
 * 數字一律轉成 Double：Apple 送來的 `120` 與這裡的 `120.0` 要算同一個值，
 * 否則每一次比對都以為欄位變了，然後把同一個值來回廣播。
 */
object CollabJson {

    fun flatten(json: JSONObject, prefix: String): Map<String, Any> {
        val out = LinkedHashMap<String, Any>()
        for (key in json.keys()) {
            val value = json.opt(key)
            val path = prefix + key
            if (value is JSONObject && value.length() > 0) {
                out.putAll(flatten(value, "$path."))
            } else {
                out[path] = toKotlin(value)
            }
        }
        return out
    }

    fun unflatten(fields: Map<String, Any>, prefix: String): JSONObject {
        val root = JSONObject()
        for ((key, value) in fields) {
            if (!key.startsWith(prefix)) continue
            val parts = key.removePrefix(prefix).split('.').filter { it.isNotEmpty() }
            if (parts.isEmpty()) continue
            var node = root
            for (part in parts.dropLast(1)) {
                node = node.optJSONObject(part) ?: JSONObject().also { node.put(part, it) }
            }
            node.put(parts.last(), toJson(value))
        }
        return root
    }

    fun toKotlin(value: Any?): Any = when (value) {
        null, JSONObject.NULL -> JsonNull
        is JSONArray -> (0 until value.length()).map { toKotlin(value.opt(it)) }
        is JSONObject -> fromJsonObject(value)
        is Number -> value.toDouble()
        else -> value
    }

    fun toJson(value: Any?): Any = when (value) {
        null, JsonNull -> JSONObject.NULL
        is List<*> -> JSONArray().also { array -> value.forEach { array.put(toJson(it)) } }
        is Map<*, *> -> JSONObject().also { obj -> value.forEach { (k, v) -> obj.put(k.toString(), toJson(v)) } }
        else -> value
    }

    fun fromJsonObject(obj: JSONObject): Map<String, Any> {
        val out = LinkedHashMap<String, Any>()
        for (key in obj.keys()) out[key] = toKotlin(obj.opt(key))
        return out
    }

    fun toJsonObject(map: Map<String, Any>): JSONObject {
        val obj = JSONObject()
        for ((k, v) in map) obj.put(k, toJson(v))
        return obj
    }
}

// ── 格式錨點（設計 §8.3）──────────────────────────────────────

/**
 * 逐字格式的區段以「字的 id」標出頭尾，而不是位置。
 *
 * 位置會隨同時打字而偏移（對方在前面插了三個字，送來的「第 10–15 字粗體」就粗錯了字）；
 * id 不會。送出時把每段的頭尾換成 id，收到後以自己的 CRDT 換回現在的位置。與 Apple 端 `CollabRunAnchors` 相同。
 */
object CollabRunAnchors {
    /** 每段 `(start, length)` → `[第一個字的 id, 最後一個字的 id]`；找不到的是 `["", ""]`。 */
    fun anchors(runs: List<Pair<Int, Int>>, text: CollabText): List<List<String>> = runs.map { (start, length) ->
        val first = text.idAt(start)
        val last = if (length > 0) text.idAt(start + length - 1) else null
        if (first != null && last != null) listOf(first, last) else listOf("", "")
    }

    /** 錨點 → 現在的 `(start, length)`。認不得、或整段的字都被刪了的回 `null`（沿用送來的位置）。 */
    fun resolve(anchors: List<List<String>>, text: CollabText): List<Pair<Int, Int>?> = anchors.map { pair ->
        val first = pair.getOrNull(0)?.ifEmpty { null } ?: return@map null
        val last = pair.getOrNull(1)?.ifEmpty { null } ?: return@map null
        val start = text.visibleIndexOf(first, forward = true) ?: return@map null
        val end = text.visibleIndexOf(last, forward = false) ?: return@map null
        if (end < start) null else start to (end - start + 1)
    }
}
