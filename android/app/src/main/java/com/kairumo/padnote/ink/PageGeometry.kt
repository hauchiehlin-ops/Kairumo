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

    private val defaultSize: Pair<Float, Float> = runCatching {
        val values = standardPageSize()
        values[0] to values[1]
    }.getOrDefault(800f to 1132f)

    /**
     * 目前這一本筆記的頁面尺寸（S-84）。
     *
     * # 為什麼是一個「目前」而不是參數
     *
     * 畫布、底紋、分頁計算、縮圖與匯出五條路都要拿到同一個尺寸，其中幾條
     * 是純函式，手上沒有筆記本 —— 把筆記本一路傳進去要改十幾個簽名，
     * 而漏掉其中一個的症狀是「這一頁的分頁位置跟別的地方算的不一樣」。
     * Apple 端的 `PageGeometry.currentSize` 是同一個做法與同一個理由。
     *
     * **只在主執行緒動**，而且畫面上同時只會有一本筆記在編輯。
     */
    @Volatile
    private var currentSize: Pair<Float, Float> = defaultSize

    /** 換一本筆記或改了規格時呼叫。空字串或認不得的 id 回到預設（A4 直式）。 */
    fun use(formatId: String?) {
        currentSize = if (formatId.isNullOrEmpty()) {
            defaultSize
        } else {
            runCatching {
                val f = uniffi.padnote_core.pageFormat(formatId)
                f.width to f.height
            }.getOrDefault(defaultSize)
        }
    }

    val width: Float get() = currentSize.first
    val height: Float get() = currentSize.second

    /**
     * 可列印邊界的內縮。畫布上畫出來的界線與匯出的邊界就是這一圈。
     *
     * 與 Apple 端的 `PageGeometry.printableInset` 相同。
     */
    const val PRINTABLE_INSET = 24f


    /**
     * 把一個物件推回可列印範圍，回傳新的左上角（S-85）。
     *
     * 規則在核心（`clampToPrintable`），與 Apple 的 `PrintableArea.clampOrigin`
     * 是同一份 —— 各寫一套的話，同一個物件在兩台裝置上會停在不同的位置。
     *
     * 夾的是**位置**不是大小：把拖出去的物件推回邊界，而不是縮小它。
     */
    fun clampOrigin(x: Float, y: Float, width: Float, height: Float): Pair<Float, Float> {
        val clamped = runCatching {
            uniffi.padnote_core.clampToPrintable(
                uniffi.padnote_core.FfiRect(x, y, x + width, y + height),
                this.width,
                this.height,
                PRINTABLE_INSET
            )
        }.getOrNull() ?: return x to y
        return clamped.minX to clamped.minY
    }

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
