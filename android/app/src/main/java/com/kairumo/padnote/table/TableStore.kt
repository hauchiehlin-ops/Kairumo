package com.kairumo.padnote.table

import uniffi.padnote_core.PadnoteSession

/**
 * 表格的持久化。
 *
 * 走核心的 `insert_table` / `set_table_cell` / `set_block_appearance` ——
 * 與 Apple 端寫進 `.padnote` 的是同一組操作，所以表格互相打得開。
 *
 * # 為什麼內容寫兩份
 *
 * 儲存格內容走核心的**表格區塊**（`insert_table`、`set_table_cell`），
 * 樣式與合併走**區塊外觀**。表格區塊是核心原生的型別，別的讀取器看得懂；
 * 外觀是平台自訂的 JSON，核心不解讀。
 *
 * 只寫外觀的話，這張表對核心而言就只是一塊看不懂的 JSON —— 匯出 PDF、
 * 搜尋、以及日後任何一個讀取器都拿不到裡面的字。
 */
class TableStore(
    private val session: PadnoteSession?,
    private val pageId: String?
) {

    private val tables = LinkedHashMap<String, NoteTable>()

    val all: List<NoteTable> get() = tables.values.toList()

    /** 從核心讀回這一頁的表格。 */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        tables.clear()
        for (blockId in runCatching { s.tableBlockIds(page) }.getOrDefault(emptyList())) {
            val core = runCatching { s.table(blockId) }.getOrNull() ?: continue
            if (core == null) continue

            // 位置與樣式在外觀裡；讀不到時用預設值，表格本身仍然畫得出來。
            val appearance = runCatching { s.blockAppearance(blockId) }.getOrNull()
            val fromAppearance = appearance?.let { TableAppearance.decode(it) }

            val table = (fromAppearance ?: NoteTable(id = blockId)).apply {
                // 內容一律以**核心的表格區塊**為準：那是別的裝置真正寫進去的東西，
                // 外觀裡的那份可能是舊的。
                rows = core.rows.toInt()
                cols = core.cols.toInt()
                cells = core.cells.toMutableList()
                headerRow = core.headerRow
                mergedCells = core.mergedCells
                    .filter { it.size >= 4 }
                    .map {
                        NoteTableSpan(
                            it[0].toInt(), it[1].toInt(), it[2].toInt(), it[3].toInt()
                        )
                    }
                    .toMutableList()
            }
            runCatching { s.blockPosition(blockId) }.getOrNull()
                ?.takeIf { it.size >= 2 }
                ?.let { table.x = it[0]; table.y = it[1] }

            tables[blockId] = table
        }
    }

    /**
     * 新增一張表格。
     *
     * id 由核心決定 —— 自己生一個的話，核心那邊的表格區塊就是另一個 id，
     * 之後所有的 `set_table_cell` 都會寫到不存在的區塊上，而且不會報錯。
     *
     * 核心不可用時仍然回傳一張只活在記憶體裡的，介面不會因此癱掉。
     */
    fun create(table: NoteTable): NoteTable {
        val s = session
        val page = pageId
        val id = if (s != null && page != null) {
            runCatching {
                s.insertTable(
                    page, table.rows.toUInt(), table.cols.toUInt(),
                    table.cells.toList(), table.headerRow
                )
            }.getOrNull()
        } else {
            null
        }

        val created = table.copyTable().let { copy ->
            NoteTable(
                id = id ?: copy.id,
                x = copy.x, y = copy.y, width = copy.width,
                rows = copy.rows, cols = copy.cols, cells = copy.cells,
                headerRow = copy.headerRow, mergedCells = copy.mergedCells,
                fontSize = copy.fontSize, ruleColorHex = copy.ruleColorHex,
                headerBackgroundHex = copy.headerBackgroundHex
            )
        }
        tables[created.id] = created
        if (id != null) persist(created)
        return created
    }

    /**
     * 寫回核心。
     *
     * 內容逐格寫，而不是整表覆寫 —— 兩人同時編輯不同格時才不會互相覆蓋。
     */
    fun persist(table: NoteTable) {
        tables[table.id] = table
        val s = session ?: return
        runCatching {
            val core = s.table(table.id)
            if (core != null) {
                syncShape(s, table, core.rows.toInt(), core.cols.toInt())
                for (row in 0 until table.rows) {
                    for (col in 0 until table.cols) {
                        val current = core.cells.getOrNull(row * core.cols.toInt() + col)
                        val wanted = table.cell(row, col)
                        if (current != wanted) {
                            s.setTableCell(table.id, row.toUInt(), col.toUInt(), wanted)
                        }
                    }
                }
                syncMerges(s, table, core.mergedCells)
            }
            s.setBlockPosition(table.id, table.x, table.y)
            s.setBlockAppearance(table.id, TableAppearance.encode(table))
        }
    }

    /** 把核心那邊的列欄數調成與這張表一致。 */
    private fun syncShape(s: PadnoteSession, table: NoteTable, coreRows: Int, coreCols: Int) {
        repeat(maxOf(0, table.rows - coreRows)) {
            s.insertTableRow(table.id, coreRows.toUInt(), emptyList())
        }
        repeat(maxOf(0, coreRows - table.rows)) {
            s.deleteTableRow(table.id, (table.rows).toUInt())
        }
        repeat(maxOf(0, table.cols - coreCols)) {
            s.insertTableColumn(table.id, coreCols.toUInt(), emptyList())
        }
        repeat(maxOf(0, coreCols - table.cols)) {
            s.deleteTableColumn(table.id, (table.cols).toUInt())
        }
    }

    private fun syncMerges(s: PadnoteSession, table: NoteTable, existing: List<List<UInt>>) {
        for (span in existing) {
            if (span.size < 4) continue
            val stillThere = table.mergedCells.any {
                it.row == span[0].toInt() && it.col == span[1].toInt()
            }
            if (!stillThere) s.unmergeTableCell(table.id, span[0], span[1])
        }
        for (span in table.mergedCells) {
            s.mergeTableCells(
                table.id, span.row.toUInt(), span.col.toUInt(),
                span.rowSpan.toUInt(), span.colSpan.toUInt()
            )
        }
    }

    fun remove(table: NoteTable) {
        tables.remove(table.id)
        runCatching { session?.removeBlock(table.id) }
    }
}
