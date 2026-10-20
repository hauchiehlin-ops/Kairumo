package com.kairumo.padnote.collab

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 協定積木：與 Apple 端 `CollabProtocolTests` **共用同一組測試向量**。
 * 兩邊算出不同的答案，就是兩個人看到不同的筆記。
 */
class CollabProtocolTest {

    private fun exchange(base: String, editA: String, editB: String): Pair<String, String> {
        val a = CollabText(base, "A")
        val b = CollabText(base, "B")
        val opsA = a.localEdit(base, editA)
        val opsB = b.localEdit(base, editB)
        opsB.forEach { a.apply(it) }
        opsA.forEach { b.apply(it) }
        return a.text to b.text
    }

    @Test fun vectorConcurrentInsertAtTheSameSpot() {
        val (a, b) = exchange("abc", "abXc", "abYc")
        assertEquals(a, b)
        assertEquals("abYXc", a)
    }

    @Test fun vectorTypingAtTheSameSpotDoesNotInterleave() {
        val (a, b) = exchange("ab", "12ab", "xyab")
        assertEquals(a, b)
        assertEquals("xy12ab", a)
    }

    @Test fun vectorConcurrentDeleteAndInsert() {
        val (a, b) = exchange("hello", "helo", "hello!")
        assertEquals(a, b)
        assertEquals("helo!", a)
    }

    @Test fun vectorBothDeleteTheSameCharacter() {
        val (a, b) = exchange("abc", "ac", "ac")
        assertEquals("ac", a)
        assertEquals("ac", b)
    }

    @Test fun outOfOrderOpsWaitForTheirAnchor() {
        val a = CollabText("", "A")
        val b = CollabText("", "B")
        a.localEdit("", "hey").reversed().forEach { b.apply(it) }
        assertEquals("hey", b.text)
        assertFalse(b.hasPending)
    }

    @Test fun opsRoundTripThroughJson() {
        val a = CollabText("x", "A")
        (a.localEdit("x", "xy") + a.localEdit("xy", "y")).forEach {
            assertEquals(it, CollabText.Op.fromJson(it.toJson()))
        }
    }

    @Test fun baseHashMatchesApple() {
        // 兩平台對同一份基準算出同一個雜湊，才認得出「基準相同、可以逐字合併」。
        assertEquals(CollabText.hash("hello"), CollabText("hello", "A").baseHash)
        assertEquals(16, CollabText.hash("hello").length)
        // 與 Apple 端 `CollabProtocolTests` 同一個向量：SHA-256("hello") 的前 8 個位元組。
        assertEquals("2cf24dba5fb0a30e", CollabText.hash("hello"))
    }

    @Test fun runAnchorsFollowTheirCharactersUnderConcurrentTyping() {
        // 與 Apple 端 `testRunAnchorsFollowTheirCharacters` 同一個情境。
        val a = CollabText("hello world", "A")
        val b = CollabText("hello world", "B")
        val anchors = CollabRunAnchors.anchors(listOf(6 to 5), a) // A 把 "world" 設成粗體
        b.localEdit("hello world", "XXhello world")               // 同時 B 在最前面打了兩個字
        assertEquals(listOf(8 to 5), CollabRunAnchors.resolve(anchors, b))
    }

    @Test fun aDeletedAnchorMovesInward() {
        val a = CollabText("abcdef", "A")
        val anchors = CollabRunAnchors.anchors(listOf(1 to 3), a) // "bcd"
        a.localEdit("abcdef", "acdef")                            // "b" 被刪了
        assertEquals(listOf(1 to 2), CollabRunAnchors.resolve(anchors, a))
        a.localEdit("acdef", "aef")                               // 整段都刪了
        assertEquals(listOf(null), CollabRunAnchors.resolve(anchors, a))
    }

    @Test fun unknownAnchorsFallBack() {
        val b = CollabText("abc", "B")
        assertEquals(listOf(null), CollabRunAnchors.resolve(listOf(listOf("9@Z", "9@Z")), b))
    }

    @Test fun vectorFractionalKeys() {
        assertEquals(listOf("V", "l", "t"), FractionalIndex.initialKeys(3))
        assertEquals("d", FractionalIndex.between("V", "l"))
        assertEquals("G", FractionalIndex.between("", "V"))
        assertEquals("VV", FractionalIndex.between("V", "W"))
    }

    @Test fun keysBetweenAreAlwaysStrictlyBetween() {
        val low = "V"
        var high = "W"
        repeat(40) {
            val mid = FractionalIndex.between(low, high)
            assertTrue("$low < $mid < $high", low < mid && mid < high)
            high = mid
        }
    }

    @Test fun flattenRoundTripAndNumbersAreNormalised() {
        val json = JSONObject("""{"object":"image","image":{"width":120,"fileName":"a.png"},"runs":[1,2]}""")
        val flat = CollabJson.flatten(json, "a.")
        assertEquals(120.0, flat["a.image.width"])
        assertEquals(listOf(1.0, 2.0), flat["a.runs"])
        val back = CollabJson.unflatten(flat, "a.")
        assertEquals("a.png", back.getJSONObject("image").getString("fileName"))
    }
}

/** 記憶體裡的一份筆記本，給合併引擎測試用。 */
private class FakeCanvas(var pages: MutableList<String>) : CollabCanvas {
    val objects = LinkedHashMap<String, CollabEntry>()
    override val pageIds: List<String> get() = pages

    /** 頁面 → 堆疊順序（物件 id）。 */
    val orders = LinkedHashMap<String, MutableList<String>>()

    override fun objectOrders(): Map<String, List<String>> = orders

    /** 頁面 → 鎖定在畫布上的物件 id。 */
    val locked = LinkedHashMap<String, List<String>>()

    override fun writeStacking(
        orders: Map<String, List<String>>, under: Map<String, List<String>>, locked: Map<String, List<String>>
    ) {
        this.orders.clear()
        orders.forEach { (p, l) -> this.orders[p] = l.toMutableList() }
        this.locked.clear()
        this.locked.putAll(locked)
    }

    override fun maps(pagePositions: Map<String, String>, zPositions: Map<String, String>, allPages: Boolean): Map<String, CollabEntry> {
        val out = LinkedHashMap<String, CollabEntry>()
        for ((k, e) in objects) out[k] = e.copy(dict = e.dict + (zPositions[e.id]?.let { mapOf("z" to it) } ?: emptyMap()))
        for (p in pages) out["page:$p"] = CollabEntry("page", p, pagePositions[p]?.let { mapOf("pos" to it) } ?: emptyMap())
        return out
    }

    override fun inScope(type: String, dict: Map<String, Any>) = true

    override fun write(type: String, id: String, fields: Map<String, Any>, deleted: Boolean): Boolean {
        if (type == "page") return true
        if (!deleted && fields["page"] is String && fields["page"] !in pages) return false // 頁還沒到
        if (deleted) objects.remove("$type:$id")
        else objects["$type:$id"] = CollabEntry(type, id, fields - ObjectPatch.DELETED - "z")
        return true
    }
}

private class Replica(
    val user: String, pages: List<String>, initial: Map<String, Map<String, Any>>,
    orders: Map<String, List<String>> = emptyMap()
) {
    val canvas = FakeCanvas(pages.toMutableList())
    val sync = CollabObjectSync()
    var clock = 0L

    init {
        initial.forEach { (k, v) -> canvas.objects[k] = CollabEntry(k.substringBefore(':'), k.substringAfter(':'), v) }
        orders.forEach { (p, l) -> canvas.orders[p] = l.toMutableList() }
        sync.reset(canvas)
    }

    fun edit(change: FakeCanvas.() -> Unit): Pair<CollabOutgoing, LamportStamp> {
        canvas.change()
        clock++
        val stamp = LamportStamp(clock, user)
        return sync.outgoing(canvas, stamp) to stamp
    }

    fun receive(message: Pair<CollabOutgoing, LamportStamp>) {
        clock = maxOf(clock, message.second.lamport)
        message.first.patches.forEach { sync.apply(it, message.second, canvas) }
        val order = sync.desiredPageOrder()
        if (order.isNotEmpty()) canvas.pages = order.toMutableList()
        sync.retryDeferred(canvas)
        val (orders, under, locked) = sync.desiredStacking()
        canvas.writeStacking(orders, under, locked)
        sync.refreshShadow(canvas)
    }

    fun field(key: String, field: String) = canvas.objects[key]?.dict?.get(field)
}

class CollabSyncTest {

    private val img = "image:i1"
    private fun base() = mapOf(img to mapOf<String, Any>("page" to "p1", "x" to 10.0, "a.image.width" to 100.0))

    private fun FakeCanvas.set(key: String, field: String, value: Any) {
        val e = objects.getValue(key)
        objects[key] = e.copy(dict = e.dict + (field to value))
    }

    @Test fun concurrentEditsOfTheSameFieldConverge() {
        val a = Replica("A", listOf("p1"), base())
        val b = Replica("B", listOf("p1"), base())
        val ma = a.edit { set(img, "x", 100.0) }
        val mb = b.edit { set(img, "x", 200.0) }
        a.receive(mb); b.receive(ma)
        assertEquals(200.0, a.field(img, "x"))
        assertEquals(200.0, b.field(img, "x"))
    }

    @Test fun concurrentEditsOfDifferentFieldsAreBothKept() {
        val a = Replica("A", listOf("p1"), base())
        val b = Replica("B", listOf("p1"), base())
        val ma = a.edit { set(img, "x", 300.0) }
        val mb = b.edit { set(img, "a.image.borderColorHex", "#FF0000") }
        a.receive(mb); b.receive(ma)
        assertEquals(a.canvas.objects, b.canvas.objects)
        assertEquals("#FF0000", a.field(img, "a.image.borderColorHex"))
    }

    @Test fun aFieldOnlyTheOtherPlatformWritesIsNeverDeleted() {
        // Apple 的圖片有 materialType，Android 的編碼器不會寫。Android 改位置時不能把它抹掉。
        val a = Replica("A", listOf("p1"), base())
        val apple = Replica("Z", listOf("p1"), base())
        a.receive(apple.edit { set(img, "a.image.materialType", "paper") })
        // Android 這邊的編碼結果不含那個欄位（模擬：寫回時被丟掉）。
        a.canvas.objects[img] = a.canvas.objects.getValue(img).let { it.copy(dict = it.dict - "a.image.materialType") }
        val out = a.edit { set(img, "x", 42.0) }.first
        assertFalse(out.patches.any { p -> p.fields["a.image.materialType"] == JsonNull })
    }

    @Test fun textContentGoesThroughTheCrdt() {
        val start = mapOf("text:t1" to mapOf<String, Any>("page" to "p1", "text" to "hi"))
        val a = Replica("A", listOf("p1"), start)
        val out = a.edit { set("text:t1", "text", "hi there") }.first
        assertTrue(out.patches.none { it.fields.containsKey("text") })
        assertEquals(Triple("t1", "hi", "hi there"), out.textEdits.single())
    }

    @Test fun pagesConvergeUnderConcurrentInserts() {
        val a = Replica("A", listOf("p1", "p9"), emptyMap())
        val b = Replica("B", listOf("p1", "p9"), emptyMap())
        val ma = a.edit { pages = mutableListOf("p1", "pa", "p9") }
        val mb = b.edit { pages = mutableListOf("p1", "pb", "p9") }
        a.receive(mb); b.receive(ma)
        assertEquals(a.canvas.pages, b.canvas.pages)
        assertEquals("p1", a.canvas.pages.first())
        assertEquals("p9", a.canvas.pages.last())
        assertEquals(setOf("p1", "pa", "pb", "p9"), a.canvas.pages.toSet())
    }

    @Test fun movingAPageOnlyChangesThatPage() {
        val a = Replica("A", listOf("p1", "p2", "p3"), emptyMap())
        val out = a.edit { pages = mutableListOf("p2", "p3", "p1") }.first
        assertEquals(listOf("p1"), out.patches.filter { it.type == "page" }.map { it.id })
    }

    @Test fun deletingAndAnOlderEditDoNotResurrect() {
        val a = Replica("A", listOf("p1"), base())
        val b = Replica("B", listOf("p1"), base())
        val old = b.edit { set(img, "x", 5.0) }
        a.receive(old)
        val delete = a.edit { objects.remove(img) }
        b.receive(delete)
        a.receive(old)
        assertFalse(a.canvas.objects.containsKey(img))
        assertEquals(a.canvas.objects, b.canvas.objects)
    }

    @Test fun anObjectWaitingForItsPageIsNotSentAsDeleted() {
        val a = Replica("A", listOf("p1"), emptyMap())
        val b = Replica("B", listOf("p1"), emptyMap())
        val (out, stamp) = b.edit {
            pages.add("p2")
            objects["image:n"] = CollabEntry("image", "n", mapOf("page" to "p2", "x" to 1.0))
        }
        // 只收到物件、頁面還沒到：先擱著。
        a.receive(CollabOutgoing(out.patches.filter { it.type != "page" }, emptyList()) to stamp)
        assertFalse(a.canvas.objects.containsKey("image:n"))
        val next = a.edit { }.first
        assertTrue(next.patches.none { it.key == "image:n" })
        // 頁面到了：補上。
        a.receive(CollabOutgoing(out.patches.filter { it.type == "page" }, emptyList()) to stamp)
        assertTrue(a.canvas.objects.containsKey("image:n"))
    }

    @Test fun wireFormatMatchesApple() {
        // 同一筆修改編成 JSON 再讀回來，欄位與型別不變（Apple 端讀的是同一份）。
        val patch = ObjectPatch("text", "t1", mapOf("x" to 12.0, "a.runs" to listOf(1.0), ObjectPatch.DELETED to false))
        assertEquals(patch, ObjectPatch.fromJson(JSONObject(patch.toJson().toString())))
    }

    // ── 第四階段 ──

    private fun stacked(user: String): Replica {
        val objs = mapOf(
            "image:a" to mapOf<String, Any>("page" to "p1"), "image:b" to mapOf<String, Any>("page" to "p1"),
            "image:c" to mapOf<String, Any>("page" to "p1")
        )
        return Replica(user, listOf("p1"), objs, mapOf("p1" to listOf("a", "b", "c")))
    }

    @Test fun reorderingDifferentObjectsAtTheSameTimeKeepsBoth() {
        val a = stacked("A")
        val b = stacked("B")
        val ma = a.edit { orders["p1"] = mutableListOf("b", "c", "a") } // A 把 a 移到最上層
        val mb = b.edit { orders["p1"] = mutableListOf("a", "c", "b") } // B 把 b 移到最上層
        a.receive(mb); b.receive(ma)
        assertEquals(a.canvas.orders, b.canvas.orders)
        val order = a.canvas.orders.getValue("p1")
        // 兩個人的動作都留下：c 在最下，a、b 都在 c 之上（舊做法是整份清單 LWW，其中一人的會被蓋掉）。
        assertEquals("c", order.first())
        assertEquals(setOf("a", "b"), order.drop(1).toSet())
    }

    @Test fun movingOneObjectOnlySendsThatObject() {
        val a = stacked("A")
        val out = a.edit { orders["p1"] = mutableListOf("a", "c", "b") }.first
        assertEquals(listOf("image:b"), out.patches.map { it.key })
    }

    @Test fun lockingDifferentObjectsAtTheSameTimeKeepsBoth() {
        // 「鎖定在畫布上」與 `under` 一樣是每個物件自己的欄位：兩人各鎖一個，兩個都鎖住。
        val a = stacked("A")
        val b = stacked("B")
        val ma = a.edit { set("image:a", "locked", true) }
        val mb = b.edit { set("image:b", "locked", true) }
        assertEquals(listOf("image:a"), ma.first.patches.map { it.key })
        a.receive(mb); b.receive(ma)
        assertEquals(mapOf("p1" to listOf("a", "b")), a.canvas.locked)
        assertEquals(a.canvas.locked, b.canvas.locked)
        // 解除鎖定也傳得過去。
        b.receive(a.edit { set("image:a", "locked", false) })
        assertEquals(mapOf("p1" to listOf("b")), b.canvas.locked)
    }

    @Test fun aJoinerAdoptsTheRoomsStateAndPushesWhatOnlyItHas() {
        val room = Replica("R", listOf("p1"), base())
        room.receive(room.edit { set(img, "x", 42.0) }) // 房間裡改過
        val joiner = Replica("J", listOf("p1"), base() + ("image:mine" to mapOf("page" to "p1", "x" to 1.0)))
        joiner.canvas.set(img, "x", 10.0) // 加入者的檔案比較舊
        joiner.sync.reset(joiner.canvas)
        val result = joiner.sync.applySnapshot(room.sync.snapshot(), joiner.canvas)
        assertTrue(result.changed)
        assertEquals(42.0, joiner.field(img, "x"))
        // 只有自己有的物件：忘掉之後下一次送出會把它整個送出去。
        val localOnly = joiner.sync.liveKeys.filter { it != "meta:notebook" && it !in room.sync.liveKeys }
        assertEquals(listOf("image:mine"), localOnly)
        joiner.sync.forget(localOnly)
        val push = joiner.edit { }.first
        assertTrue(push.patches.any { it.key == "image:mine" && it.fields[ObjectPatch.DELETED] == false })
    }

    @Test fun theRoomsBaselineLosesToARealEdit() {
        val joiner = Replica("J", listOf("p1"), base())
        joiner.receive(joiner.edit { set(img, "x", 7.0) }) // 加入者在加入後真的改了
        val room = Replica("R", listOf("p1"), base())
        joiner.sync.applySnapshot(room.sync.snapshot(), joiner.canvas)
        assertEquals(7.0, joiner.field(img, "x"))
    }

    @Test fun snapshotEntriesRoundTripThroughJson() {
        val room = Replica("R", listOf("p1"), base())
        room.receive(room.edit { set(img, "x", 3.0) })
        val entries = room.sync.snapshot()
        val back = entries.map { SnapshotEntry.fromJson(JSONObject(it.toJson().toString()))!! }
        assertEquals(entries.map { it.type to it.id }, back.map { it.type to it.id })
        assertEquals(entries.first { it.id == "i1" }.groups.keys, back.first { it.id == "i1" }.groups.keys)
    }
}
