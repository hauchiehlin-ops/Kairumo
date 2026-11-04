package com.kairumo.padnote.canvas

/**
 * 側欄縮圖的新鮮度：哪幾頁的「基底縮圖」已經過期、不能再拿來頂替（I4 畫面同源）。
 *
 * 側欄收到的 `revision` 是全本筆記的總和，任何一頁有變動所有卡片都會重跑；為了不讓一整排
 * 縮圖每次都重算，非目前頁會直接沿用上一張基底縮圖。這在「那一頁真的沒變」時是對的。
 *
 * 漏洞在：目前頁剛貼了貼紙、縮放了圖片（revision 前進，縮圖還在 180ms 去抖動裡）時就切到別頁，
 * 那一頁變成「非目前頁」，於是舊的基底縮圖被當成最新 —— 畫布上有貼紙、側欄卻永遠沒有。
 *
 * 所以目前頁一看到 revision 前進就把自己標成「髒」，直到真的重算出新縮圖才清掉；
 * 髒的頁面即使不是目前頁也不准沿用舊基底。以世代號清除：重算期間又有新變動的話，
 * 舊那一輪算完不能把新的髒標記洗掉。
 *
 * 只在主執行緒讀寫（縮圖的 LaunchedEffect 與 `Dispatchers.Main.immediate` 區塊），仍加鎖以防萬一。
 */
// profile-scope: profile 頁面縮圖髒標記（頁面 id 為全域 UUID，換設定檔時隨 `clearPageThumbnailCache` 一併清空）
object ThumbnailFreshness {
    private val lock = Any()
    private val dirtyGeneration = HashMap<String, Int>()
    private var nextGeneration = 1

    /** 標記這一頁的內容已變動。回傳本次的世代號。 */
    fun markDirty(pageId: String): Int = synchronized(lock) {
        val gen = nextGeneration++
        dirtyGeneration[pageId] = gen
        gen
    }

    fun isDirty(pageId: String): Boolean = synchronized(lock) { dirtyGeneration.containsKey(pageId) }

    /** 目前的髒世代號；乾淨時為 0。開始重算前先記下，算完用它清除。 */
    fun generation(pageId: String): Int = synchronized(lock) { dirtyGeneration[pageId] ?: 0 }

    /** 縮圖已依 [generation] 那一版重算完成。期間又被標髒（世代號不同）就保留髒標記。 */
    fun markRendered(pageId: String, generation: Int) = synchronized(lock) {
        if (dirtyGeneration[pageId] == generation) dirtyGeneration.remove(pageId)
    }

    fun reset() = synchronized(lock) {
        dirtyGeneration.clear()
    }

    /**
     * 能不能直接沿用基底縮圖、不重算。
     *
     * - 目前頁：只有上一次就是依這個 revision 算的才行。
     * - 非目前頁：只要它沒被標髒就行（全域 revision 前進不代表這一頁變了）。
     */
    fun canReuseBase(
        hasBase: Boolean,
        isCurrent: Boolean,
        lastRenderedRevision: Int,
        revision: Int,
        isDirty: Boolean
    ): Boolean {
        if (!hasBase) return false
        return if (isCurrent) lastRenderedRevision == revision && !isDirty else !isDirty
    }

    /** 目前頁看到 revision 前進（上一次不是依這一版算的），就代表它的內容可能變了。 */
    fun currentPageChanged(isCurrent: Boolean, lastRenderedRevision: Int, revision: Int): Boolean =
        isCurrent && lastRenderedRevision != -1 && lastRenderedRevision != revision
}
