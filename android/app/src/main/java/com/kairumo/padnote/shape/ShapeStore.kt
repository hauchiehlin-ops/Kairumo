package com.kairumo.padnote.shape

import uniffi.padnote_core.FfiAnchor
import uniffi.padnote_core.FfiEndCap
import uniffi.padnote_core.FfiObjectKind
import uniffi.padnote_core.FfiRouteStyle
import uniffi.padnote_core.PadnoteSession

/**
 * 形狀的持久化。
 *
 * 走核心的 `insert_shape` 與 `shape_object` —— 形狀因此是**核心的原生物件**，
 * 不是平台自己另外存的一份 JSON。差別在於：原生物件跨得過平台、進得了匯出，
 * 而平台自存的那份只有這台裝置看得懂。
 *
 * 只寫在記憶體裡的話，關掉 App 形狀就沒了 —— 那是使用者第一天就會遇到的事。
 */
class ShapeStore(
    private val session: PadnoteSession?,
    private val pageId: String?
) {

    private val shapes = LinkedHashMap<String, NoteShape>()
    private val connections = LinkedHashMap<String, NoteConnection>()

    val all: List<NoteShape> get() = shapes.values.toList()
    val allConnections: List<NoteConnection> get() = connections.values.toList()

    /** 從核心讀回這一頁的形狀與連接線，依堆疊順序。 */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        shapes.clear()
        connections.clear()
        val objects = runCatching { s.rootObjects(page) }.getOrDefault(emptyList())
        for (node in objects) {
            if (node.kind == FfiObjectKind.CONNECTION) {
                // 連接線也要讀回來 —— 少了它，另一台裝置看到的是一堆
                // 沒有線連起來的方塊。
                val core = runCatching { s.connectionObject(page, node.id) }.getOrNull()
                if (core != null) {
                    connections[node.id] = NoteConnection(
                        id = node.id,
                        fromShapeId = core.fromObjectId,
                        toShapeId = core.toObjectId,
                        label = core.label
                    )
                }
                continue
            }
            if (node.kind != FfiObjectKind.SHAPE) continue
            val core = runCatching { s.shapeObject(page, node.id) }.getOrNull() ?: continue
            if (core == null) continue

            // 位移走的是**變換**，不會改寫形狀的原始邊界（ADR-0010：
            // 位移不改寫取樣點）。不把變換套上去的話，搬動過的形狀每次重開
            // 都會跳回原位 —— 而且檔案裡其實是對的。
            val transform = runCatching { s.objectTransform(page, node.id) }.getOrNull()
            val dx = transform?.getOrNull(4) ?: 0f
            val dy = transform?.getOrNull(5) ?: 0f

            shapes[node.id] = NoteShape(
                id = node.id,
                kindName = NoteShape.nameOf(core.kind),
                x = core.minX + dx,
                y = core.minY + dy,
                width = core.maxX - core.minX,
                height = core.maxY - core.minY,
                cornerRadius = core.cornerRadius,
                label = core.text
            )
        }
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

        val created = shape.copyShape().let { copy ->
            NoteShape(
                id = id ?: copy.id,
                kindName = copy.kindName,
                x = copy.x, y = copy.y, width = copy.width, height = copy.height,
                cornerRadius = copy.cornerRadius, label = copy.label,
                strokeColorHex = copy.strokeColorHex, fillColorHex = copy.fillColorHex,
                lineWidth = copy.lineWidth
            )
        }
        shapes[created.id] = created
        return created
    }

    /**
     * 搬動一個形狀。
     *
     * 走 `translate_object` 而不是重新插入 —— 重新插入會換一個 id，
     * 連著它的連接線就會指向一個不存在的物件（ADR-0010：位移不改寫取樣點）。
     */
    fun persist(shape: NoteShape) {
        val previous = shapes[shape.id]
        shapes[shape.id] = shape
        val s = session ?: return
        if (previous != null) {
            val dx = shape.x - previous.x
            val dy = shape.y - previous.y
            if (dx != 0f || dy != 0f) {
                runCatching { s.translateObject(shape.id, dx, dy) }
            }
        }
    }

    /**
     * 連起兩個形狀。
     *
     * 端點用的是**核心的物件 id**。用平台自己生的 id 的話，線會連到不存在的
     * 物件上 —— 畫面上是一條從空氣連出來的線。
     */
    fun connect(from: NoteShape, to: NoteShape, label: String = ""): NoteConnection? {
        val s = session ?: return null
        val page = pageId ?: return null
        val id = runCatching {
            s.insertConnection(
                page, from.id, to.id,
                FfiAnchor.CENTER, FfiAnchor.CENTER,
                FfiRouteStyle.STRAIGHT,
                FfiEndCap.NONE, FfiEndCap.ARROW,
                label
            )
        }.getOrNull() ?: return null

        val connection = NoteConnection(
            id = id, fromShapeId = from.id, toShapeId = to.id, label = label)
        connections[id] = connection
        return connection
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
        connections.values.filter { it.fromShapeId == shape.id || it.toShapeId == shape.id }
            .forEach { remove(it) }
        runCatching { session?.removeObject(shape.id) }
    }

    fun remove(connection: NoteConnection) {
        connections.remove(connection.id)
        runCatching { session?.removeObject(connection.id) }
    }
}
