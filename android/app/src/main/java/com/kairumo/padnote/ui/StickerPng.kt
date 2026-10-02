package com.kairumo.padnote.ui

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import java.io.ByteArrayOutputStream
import uniffi.padnote_core.FfiPathVerb
import uniffi.padnote_core.stickerCanvasSize
import uniffi.padnote_core.stickerDrawing

/**
 * 把內建貼紙算繪成透明底 PNG，供插進頁面當**圖片物件**。
 *
 * # 為什麼不再貼成筆跡
 *
 * 貼成筆跡的話，確認之後它就跟手寫的字混在一起：點它沒有反應、沒有把手、沒有刪除，
 * 只有切到套索再精準圈住才搬得動 —— 使用者不知道要這樣做，回報的是「貼上去之後
 * 就不能移動、編輯、刪除」。圖片物件則是點一下就有把手，搬移、縮放、旋轉、刪除、
 * 調圖層、框選、同步與匯出全部現成。Apple 端同一個做法（`insertStickerObject`），
 * 路徑資料同樣來自核心，兩邊的笑臉仍是同一個笑臉。
 *
 * 算繪不出來時回 null，呼叫端顯示訊息即可。
 *
 * @param colorRgba 主線色（與筆跡引擎同一個 4 位元組格式）。
 * @param px 輸出邊長（像素）。貼紙是向量，預留放大的餘裕。
 */
fun renderStickerPng(code: String, colorRgba: ByteArray, px: Int = 480): ByteArray? = runCatching {
    val unit = stickerCanvasSize()
    val scale = px / unit
    val ink = android.graphics.Color.argb(
        colorRgba[3].toInt() and 0xFF,
        colorRgba[0].toInt() and 0xFF,
        colorRgba[1].toInt() and 0xFF,
        colorRgba[2].toInt() and 0xFF
    )
    val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)
    stickerDrawing(code).forEach { item ->
        val path = Path()
        item.segs.forEach { s ->
            when (s.verb) {
                FfiPathVerb.MOVE -> path.moveTo(s.x * scale, s.y * scale)
                FfiPathVerb.LINE -> path.lineTo(s.x * scale, s.y * scale)
                FfiPathVerb.CURVE -> path.cubicTo(
                    s.c1x * scale, s.c1y * scale, s.c2x * scale, s.c2y * scale,
                    s.x * scale, s.y * scale
                )
                FfiPathVerb.CLOSE -> path.close()
            }
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
            strokeWidth = maxOf(1f, item.width * scale)
            color = if (item.accent) accentTint(ink) else ink
        }
        canvas.drawPath(path, paint)
    }
    val out = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
    out.toByteArray()
}.getOrNull()

/** 強調色：色相拉到紅色，飽和度與亮度至少 0.75／0.7 —— 與 Apple 的 `accentTint` 同一條規則。 */
private fun accentTint(color: Int): Int {
    val hsv = FloatArray(3)
    android.graphics.Color.colorToHSV(color, hsv)
    return android.graphics.Color.HSVToColor(
        android.graphics.Color.alpha(color),
        floatArrayOf(0f, maxOf(hsv[1], 0.75f), maxOf(hsv[2], 0.7f))
    )
}
