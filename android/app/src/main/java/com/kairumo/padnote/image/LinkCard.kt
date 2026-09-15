package com.kairumo.padnote.image

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import java.io.ByteArrayOutputStream
import okhttp3.OkHttpClient
import okhttp3.Request
import uniffi.padnote_core.FfiLinkMetadata
import uniffi.padnote_core.linkNormalizeUrl
import uniffi.padnote_core.linkParseMetadata

/**
 * 連結卡片（Android）。
 *
 * # 解析在核心，這裡只做 HTTP 與畫圖
 *
 * 與 `DriveHttpClient` 同一個分工。Apple 那一側叫的是同一個
 * `link_parse_metadata` —— 各寫一份正規表示式的話，兩邊遲早會分岔，
 * 而症狀是「同一個網址在 iPad 上抓得到標題、在 Android 上抓不到」。
 *
 * # 為什麼卡片是一張圖
 *
 * 核心沒有「連結」這種區塊型別，兩個平台都是**算繪成 PNG 存成圖片區塊**，
 * 並在外觀 JSON 上標 `objectKind = "link"`。這樣它跟著同步走、跟著匯出走，
 * 而且在還不認得這個型別的舊版本上仍然看得到內容（只是不能編輯）。
 *
 * 與 3D 模型那條路一樣。形狀之所以不這樣做，是因為形狀是核心的原生物件。
 *
 * # 抓不到就顯示主機名，**不要編**
 *
 * 核心的 `link_parse_metadata` 已經保證了這件事：HTML 給空字串時，標題退回
 * 主機名、描述退回網址本身。這裡不要再加任何「知名網站的預設描述」——
 * 那是捏造的中繼資料，使用者分不出哪一段是真的。
 */
object LinkCard {

    /** 卡片尺寸（頁面點）。與 Apple 端一致，同一份筆記在兩邊才一樣大。 */
    private const val CARD_WIDTH = 280f
    private const val CARD_HEIGHT = 96f

    /** 算繪用的倍率。卡片上有字，1x 算出來在高解析度螢幕上會糊。 */
    private const val RENDER_SCALE = 3f

    /**
     * 抓一個網址的中繼資料。**會阻塞網路 I/O，要在背景執行緒呼叫。**
     *
     * 抓失敗時仍然回一份結果（退回主機名），不丟例外 ——
     * 連不上網就不能插入連結，對使用者沒有道理。
     */
    fun fetch(rawUrl: String, http: OkHttpClient = shared): FfiLinkMetadata {
        val url = linkNormalizeUrl(rawUrl)
        val html = runCatching {
            val request = Request.Builder()
                .url(url)
                // 有些站台會對沒有 UA 的請求回 403。
                .header("User-Agent", "Mozilla/5.0 (Linux; Android 14)")
                .get()
                .build()
            http.newCall(request).execute().use { response ->
                if (response.isSuccessful) response.body?.string().orEmpty() else ""
            }
        }.getOrDefault("")
        return linkParseMetadata(html, url)
    }

    /**
     * 把一份中繼資料畫成卡片 PNG。
     *
     * 版面與 Apple 端一致：左邊一條強調色的邊、標題粗體、描述兩行、
     * 底下一行網站名。兩邊畫得不一樣的話，同一份筆記在兩台裝置上看起來
     * 就是兩份不同的東西。
     */
    fun render(meta: FfiLinkMetadata): ByteArray? = runCatching {
        val w = (CARD_WIDTH * RENDER_SCALE).toInt()
        val h = (CARD_HEIGHT * RENDER_SCALE).toInt()
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bmp)
        val s = RENDER_SCALE

        val bg = Paint().apply { color = Color.WHITE; isAntiAlias = true }
        canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), 10f * s, 10f * s, bg)

        val border = Paint().apply {
            color = Color.parseColor("#E0E0E5")
            style = Paint.Style.STROKE
            strokeWidth = 1f * s
            isAntiAlias = true
        }
        canvas.drawRoundRect(
            RectF(0.5f * s, 0.5f * s, w - 0.5f * s, h - 0.5f * s), 10f * s, 10f * s, border
        )

        // 左邊那一條強調色：讓卡片一眼看得出是連結而不是一張圖。
        val accent = Paint().apply { color = Color.parseColor("#1E6FD9"); isAntiAlias = true }
        canvas.drawRoundRect(RectF(0f, 0f, 4f * s, h.toFloat()), 2f * s, 2f * s, accent)

        val title = Paint().apply {
            color = Color.parseColor("#1C1C1E")
            textSize = 14f * s
            isFakeBoldText = true
            isAntiAlias = true
        }
        val body = Paint().apply {
            color = Color.parseColor("#6E6E73")
            textSize = 11f * s
            isAntiAlias = true
        }
        val site = Paint().apply {
            color = Color.parseColor("#1E6FD9")
            textSize = 10f * s
            isAntiAlias = true
        }

        val left = 14f * s
        val maxWidth = w - left - 12f * s
        canvas.drawText(ellipsize(meta.title, title, maxWidth), left, 24f * s, title)

        // 描述兩行。超過就截斷 —— 讓它溢出卡片的話，下面的網站名會被蓋掉。
        val lines = wrap(meta.description, body, maxWidth, maxLines = 2)
        var y = 42f * s
        for (line in lines) {
            canvas.drawText(line, left, y, body)
            y += 14f * s
        }
        canvas.drawText(ellipsize(meta.siteName, site, maxWidth), left, 84f * s, site)

        ByteArrayOutputStream().use { out ->
            bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
            out.toByteArray()
        }
    }.getOrNull()

    /** 卡片的顯示尺寸（頁面點）。 */
    fun cardSize(): Pair<Float, Float> = CARD_WIDTH to CARD_HEIGHT

    private fun ellipsize(text: String, paint: Paint, maxWidth: Float): String {
        if (paint.measureText(text) <= maxWidth) return text
        var end = text.length
        while (end > 1 && paint.measureText(text.substring(0, end) + "…") > maxWidth) {
            end--
        }
        return text.substring(0, end) + "…"
    }

    private fun wrap(text: String, paint: Paint, maxWidth: Float, maxLines: Int): List<String> {
        val out = mutableListOf<String>()
        var rest = text.trim()
        while (rest.isNotEmpty() && out.size < maxLines) {
            if (out.size == maxLines - 1) {
                out += ellipsize(rest, paint, maxWidth)
                break
            }
            var end = rest.length
            while (end > 1 && paint.measureText(rest.substring(0, end)) > maxWidth) {
                end--
            }
            out += rest.substring(0, end)
            rest = rest.substring(end).trimStart()
        }
        return out
    }

    /** 共用連線池。每抓一個連結都開一個 client 會白白重建 TLS 連線。 */
    private val shared = OkHttpClient()
}
