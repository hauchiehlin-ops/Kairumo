package com.kairumo.padnote.library

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** 鎖定在畫布上：中繼資料的讀寫與 Apple `NotebookDocument.lockedObjectIdsByPage` 同一個格式。 */
class ObjectLockMetaTest {

    private fun meta() = NotebookMeta.load(null)

    @Test fun lockWritesThePageKeyedListAppleReads() {
        val meta = meta()
        meta.setObjectLocked(null, 2, "b", true)
        meta.setObjectLocked(null, 2, "a", true)
        val map = meta.raw(NotebookMeta.KEY_LOCKED_BY_PAGE) as JSONObject
        // 排序寫出：同一組物件每次都是同一份內容，同步才不會誤判「有變動」（與 Apple 一致）。
        assertEquals("[\"a\",\"b\"]", map.getJSONArray("2").toString())
        assertEquals(setOf("a", "b"), meta.lockedObjectIds())
    }

    @Test fun lookupIgnoresWhichPageKeyTheIdIsFiledUnder() {
        // 頁面搬移之後頁次鍵對不上：查詢不分頁，照樣認得出鎖定的物件。
        val meta = meta()
        meta.setObjectLocked(null, 0, "x", true)
        meta.setObjectLocked(null, 5, "y", true)
        assertEquals(setOf("x", "y"), meta.lockedObjectIds())
    }

    @Test fun unlockRemovesTheIdFromEveryPageAndDropsEmptyKeys() {
        val meta = meta()
        meta.setObjectLocked(null, 0, "x", true)
        meta.setObjectLocked(null, 3, "x", true)
        meta.setObjectLocked(null, 3, "z", true)
        meta.setObjectLocked(null, 1, "x", false)
        assertEquals(setOf("z"), meta.lockedObjectIds())
        val map = meta.raw(NotebookMeta.KEY_LOCKED_BY_PAGE) as JSONObject
        assertTrue(!map.has("0"))
        meta.setObjectLocked(null, 3, "z", false)
        // 全部解除之後整個鍵拿掉，跟從來沒鎖過的筆記一模一樣。
        assertNull(meta.raw(NotebookMeta.KEY_LOCKED_BY_PAGE))
    }
}
