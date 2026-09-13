package com.kairumo.padnote.shape

/**
 * 形狀的堆疊順序與群組（Android）。
 *
 * # 為什麼是純函式
 *
 * 順序的錯誤不會跳例外，只會讓畫面上的東西**疊錯**：該在上面的跑到下面、
 * 群組裡的成員被別的東西夾在中間。那種錯只有測試抓得到，而 Compose 的
 * 視圖測不了 —— 所以規則放在這裡，視圖只負責呼叫。
 *
 * 清單的順序就是堆疊順序：索引 0 在最底層。與 Apple 的 `ObjectLayerOps`
 * 是同一組規則、同一組測試案例。
 */
object ObjectLayer {

    /** 面板要顯示的一列：群組收成一列，未分組的形狀各自一列。 */
    data class Row(
        val id: String,
        val isGroup: Boolean,
        val memberCount: Int,
        val label: String,
        val kindName: String
    )

    fun bringToFront(id: String, shapes: List<NoteShape>): List<NoteShape> =
        move(id, shapes) { _, count -> count - 1 }

    fun sendToBack(id: String, shapes: List<NoteShape>): List<NoteShape> =
        move(id, shapes) { _, _ -> 0 }

    fun bringForward(id: String, shapes: List<NoteShape>): List<NoteShape> =
        move(id, shapes) { index, count -> minOf(index + 1, count - 1) }

    fun sendBackward(id: String, shapes: List<NoteShape>): List<NoteShape> =
        move(id, shapes) { index, _ -> maxOf(index - 1, 0) }

    private fun move(
        id: String,
        shapes: List<NoteShape>,
        destination: (index: Int, count: Int) -> Int
    ): List<NoteShape> {
        val index = shapes.indexOfFirst { it.id == id }
        if (index < 0) return shapes
        val target = destination(index, shapes.size)
        // 夾住而不是繞回去：已經在最上層還按「上移」，東西不該跑到最底下。
        if (target == index || target !in shapes.indices) return shapes
        val mutable = shapes.toMutableList()
        val item = mutable.removeAt(index)
        mutable.add(target, item)
        return mutable
    }

    /**
     * 把選取的形狀收成一組，回傳新的清單與群組 id。
     *
     * 少於兩個不成組 —— 一個物件的「群組」沒有意義，而且解散之後使用者會發現
     * 什麼也沒變，只會覺得按鈕壞了。
     */
    fun group(ids: Set<String>, shapes: List<NoteShape>): Pair<List<NoteShape>, String?> {
        if (shapes.count { it.id in ids } < 2) return shapes to null
        val groupId = java.util.UUID.randomUUID().toString()
        return shapes.map {
            if (it.id in ids) it.copyShape().apply { this.groupId = groupId } else it
        } to groupId
    }

    /** 解散一個群組。成員留在原地，只是不再是一組。 */
    fun ungroup(groupId: String, shapes: List<NoteShape>): List<NoteShape> =
        shapes.map {
            if (it.groupId == groupId) it.copyShape().apply { this.groupId = null } else it
        }

    /**
     * 同一組的其他成員。
     *
     * 選到群組裡的一個，整組都要一起動 —— 那正是群組的意義。
     */
    fun groupMates(id: String, shapes: List<NoteShape>): Set<String> {
        val groupId = shapes.firstOrNull { it.id == id }?.groupId ?: return setOf(id)
        return shapes.filter { it.groupId == groupId }.map { it.id }.toSet()
    }

    /**
     * 面板的列，由**前到後**（最上層在最前面）。
     *
     * 那是圖層面板的慣例。反過來的話，使用者每按一次「上移」都要在腦中翻譯一次。
     */
    fun rows(
        shapes: List<NoteShape>,
        unnamed: String,
        groupLabel: (Int) -> String
    ): List<Row> {
        val rows = mutableListOf<Row>()
        val seen = mutableSetOf<String>()
        for (shape in shapes.reversed()) {
            val groupId = shape.groupId
            if (groupId != null) {
                if (!seen.add(groupId)) continue
                val count = shapes.count { it.groupId == groupId }
                rows.add(Row(groupId, true, count, groupLabel(count), "group"))
            } else {
                rows.add(
                    Row(
                        shape.id, false, 1,
                        shape.label.ifEmpty { unnamed },
                        shape.kindName
                    )
                )
            }
        }
        return rows
    }
}
