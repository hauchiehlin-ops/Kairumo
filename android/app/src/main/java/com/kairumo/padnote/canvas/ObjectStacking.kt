package com.kairumo.padnote.canvas

/**
 * 畫布物件的堆疊順序（誰疊在誰上面）。
 *
 * **規則與 Apple 端的 `ObjectStacking.swift` 逐條對齊** —— 兩邊的預設層級或
 * 搬移規則不同的話，同一份筆記在兩個平台的疊放結果就不一樣，而順序是會
 * 同步的，使用者只會覺得「圖層被打亂了」。
 */
object ObjectStacking {

    /**
     * 單一物件的四個排列動作。選單、編輯把手、圖層面板走同一組純函式，
     * 結果才會一致（與 Apple 端的 `ObjectReorderOp` 對應）。
     */
    enum class Reorder(val labelKey: String) {
        TO_FRONT("layer_bring_front"),
        FORWARD("layer_bring_forward"),
        BACKWARD("layer_send_backward"),
        TO_BACK("layer_send_back");

        fun apply(id: String, order: List<String>): List<String> {
            val ids = setOf(id)
            return when (this) {
                TO_FRONT -> bringToFront(ids, order)
                FORWARD -> bringForward(ids, order)
                BACKWARD -> sendBackward(ids, order)
                TO_BACK -> sendToBack(ids, order)
            }
        }
    }

    /**
     * 新插入的物件放在最上層。
     *
     * 沒有明確順序的物件，疊放次序由「型別的預設層級」決定 —— 圖片永遠在文字、
     * 表格之下，於是新貼的圖片被舊的文字蓋住，看起來像沒插進去。
     * [fresh] 是這一輪新出現的 id（依到達順序），[existing] 是這一頁其餘的物件。
     */
    fun withNewOnTop(
        existing: List<Item>,
        order: List<String>,
        fresh: List<String>
    ): List<String> = normalized(existing, order) + fresh

    /** 物件型別。`defaultLayer` 是沒有明確順序時的層級。 */
    enum class Kind(val defaultLayer: Int) {
        IMAGE(0),
        SHAPE(1),
        TABLE(2),
        CHART(3),
        MODEL3D(4),
        LINK(5),
        TEXT(6),
        PIN(7)
    }

    /** 面板上的一列。 */
    data class Item(val id: String, val kind: Kind, val title: String)

    /**
     * 一個物件的 z 值。
     *
     * 在 [order] 裡的照它的位置；不在的排到後面，同型別之間保持原本的相對次序。
     */
    fun zIndex(id: String, kind: Kind, order: List<String>): Float {
        val index = order.indexOf(id)
        if (index >= 0) return index.toFloat()
        // 沒被排過的物件放在所有排過的之上，並照型別的預設層級分層。
        return (order.size + 1 + kind.defaultLayer).toFloat()
    }

    /**
     * 把目前畫布上的物件整理成一份由後到前的清單。
     *
     * 已經刪掉的物件要剔除，否則清單會無限長大；新加進來的接在後面 ——
     * 新插入的物件預設在最上層，那是所有繪圖工具的共同慣例。
     */
    fun normalized(objects: List<Item>, order: List<String>): List<String> {
        val present = objects.map { it.id }.toSet()
        val kept = order.filter { it in present }
        val placed = kept.toSet()
        val newcomers = objects.filter { it.id !in placed }.sortedBy { it.kind.defaultLayer }
        return kept + newcomers.map { it.id }
    }

    // 四個動作。多選時整批一起動，而且**照它們目前的相對順序**動 ——
    // 不然多選搬移的結果會取決於集合的迭代順序，同樣的操作每次都不一樣。

    fun bringToFront(ids: Set<String>, order: List<String>): List<String> =
        order.filter { it !in ids } + order.filter { it in ids }

    fun sendToBack(ids: Set<String>, order: List<String>): List<String> =
        order.filter { it in ids } + order.filter { it !in ids }

    fun bringForward(ids: Set<String>, order: List<String>): List<String> {
        val result = order.toMutableList()
        // 由後往前處理：由前往後的話，先搬的會擋住後搬的。
        for (id in order.filter { it in ids }.reversed()) {
            val i = result.indexOf(id)
            if (i < 0 || i >= result.size - 1) continue
            // 上面那個也被選中時整批就卡住不動 —— 那是對的：一組一起往上，遇到頂就停。
            if (result[i + 1] in ids) continue
            val moved = result[i]
            result[i] = result[i + 1]
            result[i + 1] = moved
        }
        return result
    }

    fun sendBackward(ids: Set<String>, order: List<String>): List<String> {
        val result = order.toMutableList()
        for (id in order.filter { it in ids }) {
            val i = result.indexOf(id)
            if (i <= 0) continue
            if (result[i - 1] in ids) continue
            val moved = result[i]
            result[i] = result[i - 1]
            result[i - 1] = moved
        }
        return result
    }
}

/**
 * 物件的版面框與搬移。
 *
 * 五種型別各有自己的 store 與模型，但對齊只關心「矩形在哪、搬到哪」——
 * 收斂成兩個函式，呼叫端就不必為每種型別各寫一次。
 */
object ObjectGeometry {

    /** 物件目前的版面框（頁面座標）。認不得的 id 回傳 `null`。 */
    fun rectOf(
        id: String,
        text: com.kairumo.padnote.text.TextBoxStore,
        image: com.kairumo.padnote.image.ImageStore,
        table: com.kairumo.padnote.table.TableStore,
        chart: com.kairumo.padnote.chart.ChartStore,
        shape: com.kairumo.padnote.shape.ShapeStore
    ): uniffi.padnote_core.FfiRect? {
        text.all.firstOrNull { it.id == id }?.let {
            return rect(it.x, it.y, it.width, it.height)
        }
        image.all.firstOrNull { it.id == id }?.let {
            return rect(it.x, it.y, it.width, it.height)
        }
        table.all.firstOrNull { it.id == id }?.let {
            return rect(it.x, it.y, it.width, it.height)
        }
        chart.all.firstOrNull { it.id == id }?.let {
            return rect(it.x, it.y, it.width, it.height)
        }
        shape.all.firstOrNull { it.id == id }?.let {
            return rect(it.x, it.y, it.width, it.height)
        }
        return null
    }

    /** 把物件的左上角搬到指定座標並落盤。 */
    fun move(
        id: String,
        x: Float,
        y: Float,
        text: com.kairumo.padnote.text.TextBoxStore,
        image: com.kairumo.padnote.image.ImageStore,
        table: com.kairumo.padnote.table.TableStore,
        chart: com.kairumo.padnote.chart.ChartStore,
        shape: com.kairumo.padnote.shape.ShapeStore
    ) {
        text.all.firstOrNull { it.id == id }?.let {
            it.x = x; it.y = y; text.persist(it); return
        }
        image.all.firstOrNull { it.id == id }?.let {
            it.x = x; it.y = y; image.persist(it); return
        }
        table.all.firstOrNull { it.id == id }?.let {
            it.x = x; it.y = y; table.persist(it); return
        }
        chart.all.firstOrNull { it.id == id }?.let {
            it.x = x; it.y = y; chart.persist(it); return
        }
        shape.all.firstOrNull { it.id == id }?.let {
            shape.persist(it.copyShape().apply { this.x = x; this.y = y })
        }
    }

    private fun rect(x: Float, y: Float, w: Float, h: Float) =
        uniffi.padnote_core.FfiRect(minX = x, minY = y, maxX = x + w, maxY = y + h)
}
