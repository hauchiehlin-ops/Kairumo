package com.kairumo.padnote.image

import kotlin.math.max
import kotlin.math.min

/**
 * 圖片（含貼紙）縮放的純計算。
 *
 * **與 Apple `EditorAttachments` 的圖片縮放把手同一套規則**：等比縮放、寬下限 80、高下限 60。
 *
 * 原本 Android 圖片共用文字方塊的下限（寬 120、高 60），而貼紙預設就是 120 寬
 * —— 一插進來就已經在下限上，於是只能放大、永遠縮不回去（實機回報）。
 * 文字方塊的下限是為了「一行字放得下」，圖片沒有這個需求。
 *
 * 下限另外不超過**開始拖曳時**的尺寸：從滑桿放進來的 60 dp 小貼紙，往內一拖不能反而跳大成 80。
 */
object ImageResize {
    /** 與 Apple 圖片縮放把手的 `max(80, …)` 對齊。 */
    const val MIN_WIDTH_DP = 80f
    /** 與 Apple 圖片縮放把手的 `max(60, …)` 對齊。 */
    const val MIN_HEIGHT_DP = 60f

    /**
     * @param baseWidth 開始拖曳時的寬（頁面點）。
     * @param baseHeight 開始拖曳時的高（頁面點）。
     * @param dx 拖曳累計的水平位移（頁面點）。
     * @param dy 拖曳累計的垂直位移（頁面點）。
     * @return 新的 (寬, 高)。
     */
    fun resized(baseWidth: Float, baseHeight: Float, dx: Float, dy: Float): Pair<Float, Float> {
        val w0 = max(1f, baseWidth)
        val h0 = max(1f, baseHeight)
        val ratio = h0 / w0
        // 把拖曳投影到右下角的對角線上：往右下拉放大、往左上推縮小，
        // 斜著拖或只拖一個方向都會有反應（只看 dx 的話，往上推縮不了）。
        val diag2 = w0 * w0 + h0 * h0
        val growW = (dx * w0 + dy * h0) / diag2 * w0
        val minW = min(MIN_WIDTH_DP, w0)
        val minH = min(MIN_HEIGHT_DP, h0)
        val newW = max(minW, w0 + growW)
        val newH = max(minH, newW * ratio)
        return newW to newH
    }
}
