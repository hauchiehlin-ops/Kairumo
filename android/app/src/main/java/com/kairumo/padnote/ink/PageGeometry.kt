package com.kairumo.padnote.ink

import uniffi.padnote_core.standardPageSize

/**
 * 固定頁面幾何（問題 3＋5）。
 *
 * 尺寸取自核心的 `standard_page_size()` —— 與 Apple 端**同一個來源**。
 * 各自寫一份常數的話遲早會差一點點，而差一點點的後果是兩個平台的分頁位置
 * 不一樣：同一則筆記在 iPad 上是三頁，在 Android 上變成四頁。
 */
object PageGeometry {

    private val size: Pair<Float, Float> = runCatching {
        val values = standardPageSize()
        values[0] to values[1]
    }.getOrDefault(800f to 1132f)

    val width: Float get() = size.first
    val height: Float get() = size.second

    /**
     * 可列印邊界的內縮。畫布上畫出來的界線與匯出的邊界就是這一圈。
     *
     * 與 Apple 端的 `PageGeometry.printableInset` 相同。
     */
    const val PRINTABLE_INSET = 24f

    /** 某個 y 座標落在第幾頁（由 0 起算）。 */
    fun pageIndex(y: Float): Int = if (height <= 0f) 0 else maxOf(0, (y / height).toInt())

    /** 把跨頁的 y 換算成該頁內的 y。 */
    fun yWithinPage(y: Float): Float {
        if (height <= 0f) return y
        val remainder = y % height
        return if (remainder < 0f) remainder + height else remainder
    }

    /** 這個點是否落在頁面內。 */
    fun contains(x: Float, y: Float): Boolean =
        x >= 0f && y >= 0f && x <= width && y <= height
}
