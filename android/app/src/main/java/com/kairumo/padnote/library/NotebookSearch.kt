package com.kairumo.padnote.library

import android.content.Context

/**
 * 跨筆記本的全文搜尋（工作項 S-64）。
 *
 * # 原本只搜得到標題
 *
 * 首頁的搜尋是對著清單比對**標題**。使用者打在筆記裡的字一個都搜不到 ——
 * 而 S-61 加了 39 種文件範本之後，這件事變得很明顯：整份租賃契約的條文
 * 都在筆記裡，搜「押金」卻是零結果。
 *
 * 核心一直都有這個能力（`session.search`，背後是 CJK bigram 索引，涵蓋
 * 文字、轉錄、手寫辨識、PDF 與 OCR），只是沒有人接上去。
 *
 * # 為什麼要另外做一層
 *
 * 核心的 `search` 是**單一筆記本**的方法（它掛在 session 上）。首頁要的是
 * 「哪幾本裡面有這個字」，所以得逐本開 session 去問。
 *
 * 逐本開 session 不便宜，所以這裡做三件事：
 *
 * 1. **兩個字以下不查。** bigram 索引本來就需要兩個字，而單字查詢會命中
 *    幾乎所有東西 —— 那不是搜尋，是列全部。
 * 2. **結果照 query 快取。** 使用者刪一個字再打回來是常見動作，
 *    不該因此把整個筆記庫重開一遍。
 * 3. **開不起來的那一本略過，不讓整個搜尋失敗。** 一本壞掉的筆記不該
 *    讓其他一百本都搜不到。
 */
object NotebookSearch {

    /** 查詢字數下限。見類別說明第 1 點。 */
    const val MIN_QUERY_LENGTH = 2

    /** 每一本最多取幾筆。首頁只要知道「這本有沒有」，不需要全部命中。 */
    private const val PER_NOTEBOOK_LIMIT = 8u

    private val cache = LinkedHashMap<String, Set<String>>()
    private const val CACHE_LIMIT = 24

    /**
     * 回傳內容命中 [query] 的筆記本 id。
     *
     * **會開啟每一本筆記，必須在背景執行緒呼叫。**
     */
    fun matchingIds(
        context: Context,
        entries: List<NotebookLibrary.Entry>,
        query: String,
        deviceId: UInt
    ): Set<String> {
        val trimmed = query.trim()
        if (trimmed.length < MIN_QUERY_LENGTH) return emptySet()

        val key = "${trimmed.lowercase()}|${entries.size}"
        synchronized(cache) { cache[key] }?.let { return it }

        val hits = entries.mapNotNull { entry ->
            // 一本開不起來就跳過。讓它往外丟的話，一本壞掉的筆記會害得
            // 其他所有筆記都搜不到。
            runCatching {
                val opened = NotebookLibrary.open(context, entry.id, deviceId) ?: return@runCatching null
                val (session, _) = opened
                val results = session.search(trimmed, PER_NOTEBOOK_LIMIT)
                if (results.isEmpty()) null else entry.id
            }.getOrNull()
        }.toSet()

        synchronized(cache) {
            cache[key] = hits
            // 舊的先丟。快取只是省掉重打同一個字的成本，不需要無限長。
            while (cache.size > CACHE_LIMIT) {
                val oldest = cache.keys.firstOrNull() ?: break
                cache.remove(oldest)
            }
        }
        return hits
    }

    /** 筆記庫變動時清掉 —— 不清的話，剛寫進去的字搜不到。 */
    fun invalidate() {
        synchronized(cache) { cache.clear() }
    }
}
