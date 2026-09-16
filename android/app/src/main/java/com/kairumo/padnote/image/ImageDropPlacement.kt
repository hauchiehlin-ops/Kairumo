package com.kairumo.padnote.image

/**
 * 拖進來的圖片要放在哪、放多大（工作項 S-68，Android 端）。
 *
 * # 為什麼要算，不能直接用原圖大小
 *
 * 手機拍的照片是 4000 像素寬。照著放的話整個頁面被它蓋掉，而使用者要縮
 * 很久才看得到自己的字 —— 從「插入圖片」那條路進來的圖早就有縮放
 * （`ImageStore.insert` 的 `maxWidth`），拖進來的不能是另一套規則。
 *
 * # 為什麼要以落點為中心，還要夾回頁內
 *
 * 使用者拖到哪就是想放哪 —— 一律放左上角的話，拖放跟按「插入圖片」沒有
 * 差別。而以落點為中心的直接後果是：拖到邊邊時圖會有一半在頁面外，那一半
 * 在匯出與列印時**會被裁掉**，畫面上卻看得見。所以要夾回去。
 *
 * Apple 端是同一份規則（見 `ImageDropPlacement.swift`）。同一張圖拖到同一個
 * 位置，兩台裝置上要落在同一個地方 —— 不然同步之後版面會跑掉。
 */
object ImageDropPlacement {

    /** 拖進來的圖片預設寬度（dp）。與插入圖片那條路同一個值。 */
    const val PREFERRED_WIDTH: Float = 280f

    /** 圖片在頁面上的方框。 */
    data class Frame(val x: Float, val y: Float, val width: Float, val height: Float)

    /**
     * @param dropX 放開的位置，頁面座標。
     * @param dropY 同上。
     * @param imageWidth 圖片的原始像素寬。
     * @param imageHeight 同上。
     */
    fun frame(
        dropX: Float, dropY: Float,
        imageWidth: Float, imageHeight: Float,
        pageWidth: Float, pageHeight: Float
    ): Frame {
        // 比原圖還寬是把圖放大 —— 放大只會讓它糊掉。
        // 同時不超過頁寬的八成，否則在窄頁上一張圖就佔滿整行。
        val width = maxOf(1f, minOf(PREFERRED_WIDTH, maxOf(imageWidth, 1f), pageWidth * 0.8f))
        val aspect = if (imageWidth > 0f) imageHeight / imageWidth else 0.75f
        val height = maxOf(1f, width * aspect)

        // 夾回頁內。圖比頁面還大時（極端的長條圖）靠左上，
        // 不是讓 max 與 min 打架算出負數。
        val x = (dropX - width / 2f).coerceIn(0f, maxOf(pageWidth - width, 0f))
        val y = (dropY - height / 2f).coerceIn(0f, maxOf(pageHeight - height, 0f))

        return Frame(x, y, width, height)
    }
}
