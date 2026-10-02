package com.kairumo.padnote.platform

import com.kairumo.padnote.ink.PageGeometry
import com.kairumo.padnote.table.NoteTable
import com.kairumo.padnote.table.NoteTableSpan
import uniffi.padnote_core.PadnoteSession
import uniffi.padnote_core.PageStyle
import java.io.File

/**
 * 「匯入文件」：把 Markdown／JSON／Word／Excel 變成**目前這本筆記上**看得到、
 * 改得動的原生物件（文字方塊、表格、圖片）。對應 Apple 的 `DocumentImport.swift`。
 *
 * # 原本為什麼不對
 *
 * 1. 判斷副檔名用的是 `displayName` —— 那是**去掉副檔名**之後的名字，於是 `md`／`json`
 *    永遠不會被認出來，全部落到「嵌入文件」那一條路。
 * 2. 核心建立區塊時**沒有給位置**（每一塊都落在預設座標），一份文件展開成十個文字方塊
 *    就疊成一團，看起來像只匯進來一個。
 * 3. 超出一頁高的內容沒有地方去，被頁底吃掉。
 * 4. pptx 核心只存「張數」（預覽用的嵌入區塊），平台沒有東西能把投影片畫出來，
 *    收進來是一個空白的東西 —— 挑選器就不該列。
 *
 * # 現在的作法
 *
 * 在**暫存套件**裡讓核心解析（`importEmbedded` 會把 docx／xlsx／md／json 展開成原生區塊），
 * 讀回來之後依建立順序（區塊 id 是 UUIDv7）由上往下排版、超出的接到後面新插入的頁面。
 */
object DocumentImport {

    sealed interface Piece {
        val id: String
    }

    data class TextPiece(override val id: String, val text: String) : Piece
    data class TablePiece(override val id: String, val table: NoteTable) : Piece
    data class ImagePiece(override val id: String, val bytes: ByteArray) : Piece

    /** 文件解析出來的東西，已依文件順序排好。 */
    data class Parsed(val pieces: List<Piece>)

    /** 一個物件排好之後的位置。`pageOffset` 是相對於匯入起點頁的頁數。 */
    data class Placement(val pageOffset: Int, val y: Float)

    class EmptyDocumentException : Exception()

    /** 解析檔案。空文件丟 [EmptyDocumentException] —— 不能讓使用者看到「點了沒反應」。 */
    fun parse(scratchParent: File, file: File, title: String): Parsed {
        val scratch = File(scratchParent, "doc-import-${System.nanoTime()}.padnote")
        try {
            val session = PadnoteSession.createEmpty(
                scratch.absolutePath, title, System.currentTimeMillis().toULong(), 0xD1u)
            val pageId = session.addPage(PageStyle.BLANK)
            // **完整路徑**。核心自己讀檔，給檔名的話會在它的工作目錄底下找而失敗。
            session.importEmbedded(pageId, file.absolutePath)

            val pieces = mutableListOf<Piece>()
            for (id in session.textBlockIds(pageId)) {
                val text = session.blockText(id) ?: ""
                if (text.isNotBlank()) pieces += TextPiece(id, text)
            }
            for (id in session.tableBlockIds(pageId)) {
                val core = session.table(id) ?: continue
                val table = NoteTable(
                    id = id, rows = core.rows.toInt(), cols = core.cols.toInt(),
                    cells = core.cells.toMutableList(), headerRow = core.headerRow
                )
                table.mergedCells = core.mergedCells.filter { it.size >= 4 }
                    .map { NoteTableSpan(it[0].toInt(), it[1].toInt(), it[2].toInt(), it[3].toInt()) }
                    .toMutableList()
                pieces += TablePiece(id, table)
            }
            for (id in session.imageBlockIds(pageId)) {
                val blob = session.blockBlobId(id) ?: continue
                val bytes = runCatching { session.blobBytes(blob) }.getOrNull() ?: continue
                pieces += ImagePiece(id, bytes)
            }
            if (pieces.isEmpty()) throw EmptyDocumentException()
            return Parsed(inDocumentOrder(pieces))
        } finally {
            scratch.deleteRecursively()
        }
    }

    /**
     * 依文件順序排好。
     *
     * 區塊 id 是 UUIDv7，前 48 位元是毫秒時間戳。**不能直接比整個 id**：同一毫秒內
     * 產生的 id，後面的位元是隨機的，字串順序跟建立順序無關 —— 一份文件的十段文字
     * 會被打亂。所以只用時間戳分先後；同一毫秒（匯入時一股腦建出來，常態）維持
     * 各自在核心裡的原本順序（穩定排序），型別之間則是文字、表格、圖片。
     */
    fun inDocumentOrder(pieces: List<Piece>): List<Piece> =
        pieces.sortedWith(compareBy { it.id.replace("-", "").take(12) })

    /**
     * 文字方塊預估的高度。
     *
     * 核心建立區塊時**沒有給位置**，要由上往下排，就得先知道每一塊多高；真正的斷行
     * 在算繪時才發生，所以這裡用字寬估：ASCII 約 0.55 個字級、其餘（中日韓）約 1 個字級。
     * 估多一點比估少好 —— 少估會讓下一塊壓在上面，多估只是空白。
     */
    fun estimatedHeight(text: String, fontSize: Float, width: Float): Float {
        val usable = maxOf(40f, width - 16f)
        var lines = 0
        for (paragraph in text.split('\n')) {
            var run = 0f
            for (ch in paragraph) run += if (ch.code < 128) fontSize * 0.55f else fontSize
            lines += maxOf(1, kotlin.math.ceil(run / usable).toInt())
        }
        return lines * fontSize * 1.4f + 18f
    }

    /**
     * 把一串高度由上往下排進一頁頁的可用範圍。超出頁底的接到下一頁；
     * 單一物件比一頁還高的話獨佔一頁（不能無限往下一頁推）。
     */
    fun flow(heights: List<Float>, gap: Float = 12f): List<Placement> {
        val top = PageGeometry.PRINTABLE_INSET
        val bottom = PageGeometry.height - PageGeometry.PRINTABLE_INSET
        var page = 0
        var y = top
        val result = mutableListOf<Placement>()
        for (h in heights) {
            if (y > top && y + h > bottom) {
                page += 1
                y = top
            }
            result += Placement(page, y)
            y += h + gap
        }
        return result
    }
}
