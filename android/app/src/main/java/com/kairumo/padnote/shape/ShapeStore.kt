package com.kairumo.padnote.shape

import com.kairumo.padnote.library.NotebookMeta
import org.json.JSONObject
import uniffi.padnote_core.FfiObjectKind
import uniffi.padnote_core.PadnoteSession
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.hypot
import java.security.MessageDigest

/**
 * 形狀的持久化。
 *
 * 走核心的 `insert_shape` 與 `shape_object` —— 形狀因此是**核心的原生物件**，
 * 不是平台自己另外存的一份 JSON。差別在於：原生物件跨得過平台、進得了匯出，
 * 而平台自存的那份只有這台裝置看得懂。
 *
 * # 哪些東西存在哪裡
 *
 * - **位置、大小、旋轉**：核心的**物件變換**（平移、縮放、繞中心旋轉）。核心的形狀
 *   建立之後沒有「改外框」的 API，而變換是現成的、跨平台的、冪等的 ——
 *   Apple 端匯入時讀的是同一組（中心經過變換後的位置、兩軸縮放量、旋轉角）。
 * - **顏色、粗細、虛實、字級、種類、標籤、連接線的連接點與端點樣式**：
 *   筆記本中繼資料的 `shapeStyles`／`connectionStyles`（見 [ShapeStyleMeta]）。
 *   核心沒有這些欄位。
 *
 * 在此之前，Android 只把「建立時的外框」寫進核心：縮放、旋轉、改色之後重開 App
 * 全部回到插入時的樣子，而且同步到 Apple 也一樣。
 */
class ShapeStore(
    private val session: PadnoteSession?,
    private val pageId: String?
) {

    private val shapes = LinkedHashMap<String, NoteShape>()
    private val connections = LinkedHashMap<String, NoteConnection>()

    /**
     * 每個形狀在核心裡的**原始外框**（建立時寫進去、之後不會改）。
     * 位置、大小、旋轉是相對它的物件變換，所以要記著它才算得出變換矩陣。
     */
    private val base = HashMap<String, ShapeFrameMath.Frame>()

    /**
     * 樣式信封區塊：物件 id → 區塊 id。每個形狀、每條連接線各一個衍生圖片區塊，真身放在區塊外觀裡
     * （與 Apple 的 `ObjectEnvelope` 同一個格式）。逐物件合併 —— 兩台裝置改不同形狀不會互相覆蓋；
     * 筆記本中繼資料是整本一個暫存器（最後寫入者贏），所以不再用它存樣式（只讀舊檔）。
     */
    private val styleBlocks = HashMap<String, String>()

    val all: List<NoteShape> get() = shapes.values.toList()
    val allConnections: List<NoteConnection> get() = connections.values.toList()

    /** 從核心讀回這一頁的形狀與連接線，依堆疊順序。 */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        shapes.clear()
        connections.clear()
        base.clear()
        styleBlocks.clear()
        // 舊版寫的整本暫存器當後備，逐物件信封蓋在上面。
        val shapeStyles = NotebookMeta.load(s).shapeStyles().toMutableMap()
        val connectionStyles = NotebookMeta.load(s).connectionStyles().toMutableMap()
        for (blockId in runCatching { s.imageBlockIds(page) }.getOrDefault(emptyList())) {
            val json = runCatching { s.blockAppearance(blockId) }.getOrNull() ?: continue
            val root = runCatching { JSONObject(json) }.getOrNull() ?: continue
            val kind = root.optString("object")
            if (kind != KIND_SHAPE && kind != KIND_CONNECTION) continue
            val payload = root.optJSONObject("payload") ?: continue
            val id = payload.optString("id").lowercase()
            if (id.isEmpty()) continue
            styleBlocks[id] = blockId
            if (kind == KIND_SHAPE) shapeStyles[id] = payload else connectionStyles[id] = payload
        }
        val objects = runCatching { s.rootObjects(page) }.getOrDefault(emptyList())
        for (node in objects) {
            if (node.kind == FfiObjectKind.CONNECTION) {
                // 連接線也要讀回來 —— 少了它，另一台裝置看到的是一堆
                // 沒有線連起來的方塊。
                val core = runCatching { s.connectionObject(page, node.id) }.getOrNull()
                if (core != null) {
                    var link = NoteConnection(
                        id = node.id,
                        fromShapeId = core.fromObjectId,
                        toShapeId = core.toObjectId,
                        label = core.label
                    ).applyCore(core.fromAnchor, core.toAnchor, core.route, core.startCap, core.endCap)
                    connectionStyles[node.id.lowercase()]?.let {
                        ShapeStyleMeta.apply(it, link)
                    }
                    connections[node.id] = link
                }
                continue
            }
            if (node.kind != FfiObjectKind.SHAPE) continue
            val core = runCatching { s.shapeObject(page, node.id) }.getOrNull() ?: continue
            if (core == null) continue

            base[node.id] = ShapeFrameMath.Frame(
                core.minX, core.minY, core.maxX - core.minX, core.maxY - core.minY)
            val shape = NoteShape(
                id = node.id,
                kindName = NoteShape.nameOf(core.kind),
                x = core.minX,
                y = core.minY,
                width = core.maxX - core.minX,
                height = core.maxY - core.minY,
                cornerRadius = core.cornerRadius,
                label = core.text
            )
            // 位移、縮放、旋轉走的是**變換**，不會改寫形狀的原始邊界（ADR-0010：
            // 位移不改寫取樣點）。不把變換套上去的話，搬動過的形狀每次重開
            // 都會跳回原位 —— 而且檔案裡其實是對的。
            val transform = runCatching { s.objectTransform(page, node.id) }.getOrNull()
            if (transform != null && transform.size >= 6) applyTransform(shape, transform)
            shapeStyles[node.id.lowercase()]?.let { ShapeStyleMeta.apply(it, shape) }
            shapes[node.id] = shape
        }
    }

    /**
     * 把核心的物件變換 `[a, b, c, d, tx, ty]` 套到形狀上。
     *
     * 取**中心**經過變換後的位置當新的中心；線性部分是「先縮放、再旋轉」，
     * 兩軸的縮放量是各自那一欄的長度，旋轉角是第一欄的方向。純平移時等於
     * 原本的 `min + translation`。
     */
    private fun applyTransform(shape: NoteShape, t: List<Float>) {
        val cx0 = shape.x + shape.width / 2f
        val cy0 = shape.y + shape.height / 2f
        val nx = t[0] * cx0 + t[2] * cy0 + t[4]
        val ny = t[1] * cx0 + t[3] * cy0 + t[5]
        val sx = hypot(t[0], t[1])
        val sy = hypot(t[2], t[3])
        if (sx > 0.001f && sy > 0.001f) {
            shape.width *= sx
            shape.height *= sy
        }
        shape.x = nx - shape.width / 2f
        shape.y = ny - shape.height / 2f
        var degrees = (atan2(t[1], t[0]) * 180.0 / PI).toFloat()
        if (degrees < 0f) degrees += 360f
        // 浮點誤差：轉了又轉回來會剩下 1e-5 度，不要當成「有旋轉」存下來。
        shape.rotationDegrees = if (degrees > 0.01f && degrees < 359.99f) degrees else null
    }

    /**
     * 新增一個形狀。
     *
     * id 由核心決定 —— 自己生一個的話，核心那邊的物件就是另一個 id，
     * 之後所有的搬動與刪除都會作用在不存在的物件上，而且不會報錯。
     */
    fun create(shape: NoteShape): NoteShape {
        val s = session
        val page = pageId
        val id = if (s != null && page != null) {
            runCatching {
                s.insertShape(
                    page, shape.kind,
                    shape.x, shape.y, shape.x + shape.width, shape.y + shape.height,
                    shape.cornerRadius, shape.label
                )
            }.getOrNull()
        } else {
            null
        }

        // 帶著所有樣式複製一份，換成核心給的 id。
        val created = NoteShape.decode(
            JSONObject(shape.encodedJson()).put("id", id ?: shape.id).toString()
        ) ?: shape
        shapes[created.id] = created
        // 核心記的是建立當下的外框；之後的位置、大小、旋轉都是相對它的變換。
        base[created.id] = ShapeFrameMath.Frame(created.x, created.y, created.width, created.height)
        // 建立時就帶了旋轉（複製、範本）的話，要寫進變換；樣式也要記下來。
        if (abs(created.rotationDegrees ?: 0f) > 0.01f) writeTransform(created)
        writeStyle(KIND_SHAPE, created.id, ShapeStyleMeta.encode(created))
        return created
    }

    /**
     * 寫回一個形狀的改動：位置、大小、旋轉走變換，樣式走中繼資料。
     *
     * 走 `translate_object` 等變換而不是重新插入 —— 重新插入會換一個 id，
     * 連著它的連接線就會指向一個不存在的物件（ADR-0010：位移不改寫取樣點）。
     */
    fun persist(shape: NoteShape) {
        val previous = shapes[shape.id]
        shapes[shape.id] = shape
        if (previous == null) return
        if (geometryChanged(previous, shape)) writeTransform(shape)

        // 樣式沒變就不寫中繼資料 —— 拖曳每一幀都會走到這裡，而中繼資料是整份 JSON。
        val before = ShapeStyleMeta.encode(previous).toString()
        val after = ShapeStyleMeta.encode(shape)
        if (before != after.toString()) writeStyle(KIND_SHAPE, shape.id, after)
    }

    private fun geometryChanged(a: NoteShape, b: NoteShape): Boolean =
        abs(a.x - b.x) > 0.001f || abs(a.y - b.y) > 0.001f ||
            abs(a.width - b.width) > 0.001f || abs(a.height - b.height) > 0.001f ||
            abs((a.rotationDegrees ?: 0f) - (b.rotationDegrees ?: 0f)) > 0.001f

    /**
     * 把形狀目前的位置、大小、旋轉寫成核心的物件變換。
     *
     * **一次寫完整的矩陣。** 核心的 `translate_object`／`scale_object`／`rotate_object`
     * 底下是「設定變換」，後一次取代前一次：拖曳每一幀呼叫一次平移，重開之後只剩
     * 最後一幀的位移；縮放後再旋轉，縮放就不見了。這裡改用 `set_object_transform`，
     * 把「原始外框 → 目前狀態」整個算成一個矩陣
     * （先縮放、再繞中心旋轉、最後搬到目前的中心 —— 與讀回來時的拆解對應）。
     *
     * 走變換而不是重新插入：重新插入會換一個 id，連著它的連接線就會指向不存在的物件
     * （ADR-0010：位移不改寫取樣點）。
     */
    private fun writeTransform(target: NoteShape) {
        val s = session ?: return
        val b = base[target.id] ?: return
        if (b.width <= 0f || b.height <= 0f) return
        val sx = target.width / b.width
        val sy = target.height / b.height
        val rad = ((target.rotationDegrees ?: 0f) * PI / 180.0)
        val cos = kotlin.math.cos(rad).toFloat()
        val sin = kotlin.math.sin(rad).toFloat()
        val a = sx * cos
        val bb = sx * sin
        val c = -sy * sin
        val d = sy * cos
        val tx = target.centerX - (a * b.centerX + c * b.centerY)
        val ty = target.centerY - (bb * b.centerX + d * b.centerY)
        runCatching { s.setObjectTransform(target.id, listOf(a, bb, c, d, tx, ty)) }
    }

    /**
     * 連起兩個形狀。
     *
     * 端點用的是**核心的物件 id**。用平台自己生的 id 的話，線會連到不存在的
     * 物件上 —— 畫面上是一條從空氣連出來的線。
     */
    fun connect(from: NoteShape, to: NoteShape, label: String = ""): NoteConnection? =
        connect(NoteConnection(fromShapeId = from.id, toShapeId = to.id, label = label), from, to)

    fun connect(link: NoteConnection, from: NoteShape, to: NoteShape): NoteConnection? {
        val s = session ?: return null
        val page = pageId ?: return null
        val fields = link.coreFields(from, to)
        val id = runCatching {
            s.insertConnection(
                page, from.id, to.id,
                fields.fromAnchor, fields.toAnchor, fields.route,
                fields.startCap, fields.endCap,
                link.label
            )
        }.getOrNull() ?: return null

        val connection = link.copy(id = id, fromShapeId = from.id, toShapeId = to.id)
        connections[id] = connection
        writeStyle(KIND_CONNECTION, id, ShapeStyleMeta.encode(connection))
        return connection
    }

    /**
     * 從連接點拉線，放開在 ([dropX], [dropY])：落在哪個形狀上就連到哪個。
     *
     * 越晚畫的越在上面，所以從後往前找；轉過的形狀要把點轉回形狀自己的座標軸再判斷，
     * 才不會在轉 45° 的方塊邊角誤判。入線位置取目標形狀上離放開點最近的連接點。
     * 沒落在任何形狀上就不連（回 `null`）。
     */
    fun connectByDrag(from: NoteShape, anchor: ShapeAnchor, dropX: Float, dropY: Float): NoteConnection? {
        val target = shapes.values.toList().asReversed().firstOrNull { candidate ->
            if (candidate.id == from.id || candidate.isLinear) return@firstOrNull false
            val local = ShapeFrameMath.rotate(
                uniffi.padnote_core.FfiPoint(dropX, dropY),
                uniffi.padnote_core.FfiPoint(candidate.centerX, candidate.centerY),
                -(candidate.rotationDegrees ?: 0f).toDouble()
            )
            local.x >= candidate.x - 6f && local.x <= candidate.x + candidate.width + 6f &&
                local.y >= candidate.y - 6f && local.y <= candidate.y + candidate.height + 6f
        } ?: return null
        val toAnchor = ShapeAnchor.entries.minByOrNull {
            val p = target.anchorPoint(it)
            hypot(p.x - dropX, p.y - dropY)
        } ?: ShapeAnchor.TOP
        return connect(
            NoteConnection(
                fromShapeId = from.id, toShapeId = target.id,
                fromAnchor = anchor.raw, toAnchor = toAnchor.raw
            ),
            from, target
        )
    }

    /**
     * 改一條連接線。核心的連接線物件建立之後不能改，所以改動整包記在中繼資料裡，
     * 載入時以它為準（Apple 端匯入時同樣）。
     */
    fun persist(link: NoteConnection) {
        connections[link.id] = link
        writeStyle(KIND_CONNECTION, link.id, ShapeStyleMeta.encode(link))
    }

    /**
     * 整批換掉，順序即堆疊順序。
     *
     * 圖層面板調的是**順序**，只改個別元素的話那個順序不會反映到畫布上。
     * 核心那邊同步走 `set_object_z_index` —— 帶的是絕對索引而不是「上移一層」，
     * 因為相對操作在併發下會疊加：兩台裝置各按一次「移到最上層」，
     * 合併後會得出誰也沒預期的順序。
     */
    fun replaceAll(updated: List<NoteShape>) {
        val previous = shapes.toMap()
        shapes.clear()
        for (shape in updated) shapes[shape.id] = shape

        val s = session ?: return
        updated.forEachIndexed { index, shape ->
            runCatching { s.setObjectZIndex(shape.id, index.toUInt()) }
        }
        // 群組的變動也要寫回核心，否則換一台裝置打開群組就散了。
        syncGroups(s, previous, updated)
    }

    /** 把群組的變動寫進核心的物件樹。 */
    private fun syncGroups(
        s: PadnoteSession,
        previous: Map<String, NoteShape>,
        updated: List<NoteShape>
    ) {
        val page = pageId ?: return
        val before = previous.values.mapNotNull { it.groupId }.toSet()
        val after = updated.mapNotNull { it.groupId }.toSet()

        for (gone in before - after) {
            coreGroupIds.remove(gone)?.let { objectId ->
                runCatching { s.ungroup(objectId) }
            }
        }
        for (fresh in after - before) {
            val members = updated.filter { it.groupId == fresh }.map { it.id }
            if (members.size < 2) continue
            runCatching { s.groupObjects(page, members) }
                .getOrNull()?.let { coreGroupIds[fresh] = it }
        }
    }

    /** 平台的群組 id → 核心的 Group 物件 id。 */
    private val coreGroupIds = mutableMapOf<String, String>()

    fun remove(shape: NoteShape) {
        shapes.remove(shape.id)
        // 連著它的線也要拿掉 —— 留著的話會指向一個不存在的形狀。
        val gone = connections.values
            .filter { it.fromShapeId == shape.id || it.toShapeId == shape.id }
            .map { it.id }
        gone.forEach { id -> connections.remove(id)?.let { remove(it) } }
        runCatching { session?.removeObject(shape.id) }
        removeStyle(shape.id)
    }

    fun remove(connection: NoteConnection) {
        connections.remove(connection.id)
        runCatching { session?.removeObject(connection.id) }
        removeStyle(connection.id)
    }

    // ---- 樣式信封 ----

    /** 寫（新增或更新）一個物件的樣式信封。 */
    private fun writeStyle(kind: String, objectId: String, payload: JSONObject) {
        val s = session ?: return
        val page = pageId ?: return
        val id = objectId.lowercase()
        payload.put("id", id)
        val appearance = JSONObject()
            .put("object", kind)
            .put("image", JSONObject().put("fileName", "$id.png"))
            .put("payload", payload)
            .toString()
        runCatching {
            val existing = styleBlocks[id]
            if (existing != null) {
                s.setBlockAppearance(existing, appearance)
            } else {
                // 區塊 id 由物件 id 決定：兩台裝置各自建立也是同一個區塊，不會各長一份。
                val blockId = stableBlockId("style:$id")
                val blob = s.putBlob(TRANSPARENT_PNG)
                s.addImageWithId(page, blockId, blob, 1f, 1f)
                s.setBlockPosition(blockId, 0f, 0f)
                s.setBlockAppearance(blockId, appearance)
                styleBlocks[id] = blockId
            }
        }
    }

    private fun removeStyle(objectId: String) {
        val id = objectId.lowercase()
        val block = styleBlocks.remove(id) ?: return
        runCatching { session?.removeBlock(block) }
    }

    private companion object {
        const val KIND_SHAPE = "shapestyle"
        const val KIND_CONNECTION = "connstyle"

        /** 1×1 全透明 PNG（與 Apple 的 `ObjectEnvelope.transparentPNG` 同一張）。 */
        val TRANSPARENT_PNG: ByteArray = android.util.Base64.decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
            android.util.Base64.DEFAULT)

        /**
         * 物件 id → 核心的區塊 id。與 Apple 的 `stableBlockId` **逐步一致**：
         * 已經是 UUID 就原樣（小寫）；否則取 SHA-256 前 16 位元組並設版本與變體位元。
         */
        fun stableBlockId(raw: String): String {
            runCatching { java.util.UUID.fromString(raw) }.getOrNull()?.let {
                if (it.toString().equals(raw, ignoreCase = true)) return it.toString().lowercase()
            }
            val b = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray(Charsets.UTF_8)).copyOf(16)
            b[6] = ((b[6].toInt() and 0x0F) or 0x50).toByte()
            b[8] = ((b[8].toInt() and 0x3F) or 0x80).toByte()
            val hex = b.joinToString("") { "%02x".format(it) }
            return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-" +
                "${hex.substring(16, 20)}-${hex.substring(20)}"
        }
    }
}
