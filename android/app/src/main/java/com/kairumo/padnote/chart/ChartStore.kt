package com.kairumo.padnote.chart

import java.io.ByteArrayOutputStream
import java.util.UUID
import android.graphics.Bitmap
import uniffi.padnote_core.PadnoteSession

/**
 * 畫布上的一張圖表。
 *
 * [spec] 是使用者真正在編輯的東西；[width]/[height] 是它在頁面上佔的大小。
 */
data class ChartObject(
    val id: String,
    var spec: ChartSpec,
    var x: Float = 60f,
    var y: Float = 120f,
    var width: Float = 420f,
    var height: Float = 300f
)

/**
 * 圖表的持久化。
 *
 * 走核心的 `add_image` / `set_block_position` / `set_block_appearance` ——
 * 與 Apple 端匯出時寫進 `.padnote` 的是同一組操作。
 *
 * # 為什麼同時存點陣圖與設定
 *
 * 點陣圖進 blob，讓匯出 PDF、以及還沒支援圖表的讀取器仍然看得到東西；
 * 設定進區塊外觀，讓圖表**改得動**。只存點陣圖的話，這張圖插進去之後裡面的
 * 數字就永遠拿不回來了 —— 那正是使用者反映的問題。
 */
class ChartStore(
    private val session: PadnoteSession?,
    private val pageId: String?
) {

    private val charts = LinkedHashMap<String, ChartObject>()

    val all: List<ChartObject> get() = charts.values.toList()

    /**
     * 從核心讀回這一頁的圖表。
     *
     * 只認得外觀帶著圖表標記的圖片區塊 —— 一般的圖片照樣是圖片，不會被誤認
     * 成一張圖表而開進編輯器。
     */
    fun load() {
        val s = session ?: return
        val page = pageId ?: return
        charts.clear()
        for (blockId in runCatching { s.imageBlockIds(page) }.getOrDefault(emptyList())) {
            val json = runCatching { s.blockAppearance(blockId) }.getOrNull() ?: continue
            val spec = json?.let { ChartAppearance.decode(it) } ?: continue
            val chart = ChartObject(id = blockId, spec = spec)
            runCatching { s.blockPosition(blockId) }.getOrNull()
                ?.takeIf { it.size >= 2 }
                ?.let { chart.x = it[0]; chart.y = it[1] }
            // 尺寸拿不回來時保留預設值，而不是縮成 0 —— 那會讓圖表整個消失。
            runCatching { s.imageBlockSize(blockId) }.getOrNull()
                ?.takeIf { it.size >= 2 }
                ?.let { chart.width = it[0]; chart.height = it[1] }
            charts[blockId] = chart
        }
    }

    /** 新增一張圖表。核心不可用時仍然回傳一張只活在記憶體裡的。 */
    fun create(spec: ChartSpec, x: Float = 60f, y: Float = 120f): ChartObject {
        val chart = ChartObject(id = UUID.randomUUID().toString(), spec = spec, x = x, y = y)
        val s = session
        val page = pageId
        if (s != null && page != null) {
            val id = runCatching {
                val blob = s.putBlob(pngBytes(spec, chart.width.toInt(), chart.height.toInt()))
                s.addImage(page, blob, chart.width, chart.height)
            }.getOrNull()
            if (id != null) {
                val created = chart.copy(id = id)
                charts[id] = created
                persist(created)
                return created
            }
        }
        charts[chart.id] = chart
        return chart
    }

    /**
     * 寫回核心。
     *
     * 設定與位置都要寫 —— 少了設定，這張圖下次就只剩點陣圖，改不動了。
     */
    fun persist(chart: ChartObject) {
        charts[chart.id] = chart
        val s = session ?: return
        runCatching {
            s.setBlockPosition(chart.id, chart.x, chart.y)
            s.setBlockAppearance(chart.id, ChartAppearance.encode(chart.spec))
        }
    }

    fun remove(chart: ChartObject) {
        charts.remove(chart.id)
        runCatching { session?.removeBlock(chart.id) }
    }

    /**
     * 圖表的 PNG 位元組。
     *
     * 算繪不出來時回一組空位元組而不是拋例外：使用者按下「插入」得到一個
     * 例外訊息，比得到一張暫時畫不出來的圖更糟。
     */
    private fun pngBytes(spec: ChartSpec, width: Int, height: Int): ByteArray {
        val bitmap = ChartRenderer.bitmap(spec, width, height) ?: return ByteArray(0)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }
}
