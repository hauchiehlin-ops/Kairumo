package com.kairumo.padnote.shape

import uniffi.padnote_core.FfiObjectKind
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

    val all: List<NoteShape> get() = shapes.values.toList()

    /** 從核心讀回這一頁的形狀，依堆疊順序。 */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        shapes.clear()
        val objects = runCatching { s.rootObjects(page) }.getOrDefault(emptyList())
        for (node in objects) {
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

    fun remove(shape: NoteShape) {
        shapes.remove(shape.id)
        runCatching { session?.removeObject(shape.id) }
    }
}
