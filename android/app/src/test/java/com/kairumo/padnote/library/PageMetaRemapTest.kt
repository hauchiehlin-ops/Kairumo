package com.kairumo.padnote.library

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 搬頁、插頁、刪頁時，以頁碼記位置的中繼資料要跟著頁走。
 *
 * 原本只挪了堆疊順序與筆跡下方名單：連結卡片、錄音卡片、膠帶、錨定、圖釘、3D 模型
 * 這些帶 `pageIndex` 的清單留在原頁碼上 —— 筆跡（在核心、跟著頁面 id）搬過去了，
 * 卡片與膠帶留在原地；刪掉的頁上的卡片落到下一頁。
 */
class PageMetaRemapTest {

    private fun metaWithTapesOnEveryPage(pages: Int): NotebookMeta {
        val meta = NotebookMeta.load(null)
        val tapes = JSONArray()
        for (p in 0 until pages) tapes.put(JSONObject().put("id", "tape-$p").put("pageIndex", p))
        meta.setRaw(null, "tapeAttachments", tapes)
        meta.setObjectLocked(null, 0, "locked-on-0", true)
        return meta
    }

    private fun tapePages(meta: NotebookMeta): Map<String, Int> {
        val arr = meta.raw("tapeAttachments") as JSONArray
        return (0 until arr.length()).associate {
            arr.getJSONObject(it).getString("id") to arr.getJSONObject(it).getInt("pageIndex")
        }
    }

    @Test fun movingAPageCarriesPageIndexedListsAndKeyedMaps() {
        val meta = metaWithTapesOnEveryPage(3)
        // 第 0 頁搬到第 2 頁（與核心 `pageIndexAfterMove` 同一個結果：0→2、1→0、2→1）。
        meta.remapPageIndexes { if (it == 0) 2 else it - 1 }
        assertEquals(mapOf("tape-0" to 2, "tape-1" to 0, "tape-2" to 1), tapePages(meta))
        val locked = meta.raw(NotebookMeta.KEY_LOCKED_BY_PAGE) as JSONObject
        assertEquals("[\"locked-on-0\"]", locked.getJSONArray("2").toString())
    }

    @Test fun deletingAPageDropsItsObjectsAndShiftsTheRest() {
        val meta = metaWithTapesOnEveryPage(3)
        // 與 `removePageTemplate` 同一個規則：刪第 1 頁。
        meta.remapPageIndexes { when { it == 1 -> null; it > 1 -> it - 1; else -> it } }
        assertEquals(mapOf("tape-0" to 0, "tape-2" to 1), tapePages(meta))
    }

    @Test fun insertingAPageShiftsLaterObjects() {
        val meta = metaWithTapesOnEveryPage(2)
        meta.shiftPageKeyedData(null, fromIndex = 1, totalPagesBefore = 2)
        assertEquals(mapOf("tape-0" to 0, "tape-1" to 2), tapePages(meta))
    }
}
