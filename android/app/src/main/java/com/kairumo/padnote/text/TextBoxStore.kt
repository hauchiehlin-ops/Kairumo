package com.kairumo.padnote.text

import uniffi.padnote_core.BlockStyle
import uniffi.padnote_core.PadnoteSession
import java.util.UUID

/**
 * 文字方塊的持久化。
 *
 * 走核心的 `add_text` / `set_block_position` / `set_block_appearance` ——
 * 與 Apple 端匯出時寫進 `.padnote` 的是同一組操作，所以兩邊的文字方塊
 * 互相打得開，連顏色、邊框與段落設定都跨得過去。
 */
class TextBoxStore(
    private val session: PadnoteSession?,
    private val pageId: String?
) {

    private val boxes = LinkedHashMap<String, TextBox>()

    val all: List<TextBox> get() = boxes.values.toList()

    /** 從核心讀回這一頁的文字方塊。 */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        boxes.clear()
        for (blockId in runCatching { s.textBlockIds(page) }.getOrDefault(emptyList())) {
            val text = runCatching { s.blockText(blockId) }.getOrNull() ?: continue
            val box = TextBox(id = blockId, text = text ?: "")
            runCatching { s.blockPosition(blockId) }.getOrNull()?.let { xy ->
                if (xy != null && xy.size >= 2) {
                    box.x = xy[0]
                    box.y = xy[1]
                }
            }
            runCatching { s.blockAppearance(blockId) }.getOrNull()?.let { json ->
                if (json != null) TextBoxAppearance.apply(json, box)
            }
            boxes[blockId] = box
        }
    }

    /** 新增一個文字方塊。回傳它；核心不可用時仍然回傳一個只活在記憶體裡的。 */
    fun create(x: Float, y: Float): TextBox {
        val s = session
        val page = pageId
        val id = if (s != null && page != null) {
            runCatching { s.addText(page, "", BlockStyle.BODY) }
                .getOrElse { UUID.randomUUID().toString() }
        } else {
            UUID.randomUUID().toString()
        }
        val box = TextBox(id = id, x = x, y = y)
        boxes[id] = box
        persist(box)
        return box
    }

    /** 寫回核心。文字、位置、外觀三樣都要 —— 少一樣就會有東西跨不過平台。 */
    fun persist(box: TextBox) {
        val s = session ?: return
        boxes[box.id] = box
        runCatching {
            // 文字是 CRDT，整段換掉的做法是刪光再插入。
            val current = s.blockText(box.id) ?: ""
            if (current != box.text) {
                if (current.isNotEmpty()) {
                    s.deleteText(box.id, 0u, current.length.toUInt())
                }
                if (box.text.isNotEmpty()) s.insertText(box.id, 0u, box.text)
            }
            s.setBlockPosition(box.id, box.x, box.y)
            s.setBlockAppearance(box.id, TextBoxAppearance.encode(box))
        }
    }

    fun remove(box: TextBox) {
        boxes.remove(box.id)
        runCatching { session?.removeBlock(box.id) }
    }
}
