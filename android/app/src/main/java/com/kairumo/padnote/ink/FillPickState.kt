package com.kairumo.padnote.ink

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * 「區域填色」：下一次點畫布，就用目前的顏色填滿點到的封閉區域（與 Apple `FillPickState` 相同）。
 * 由「插入」選單開啟；畫布蓋一層接點按的透明層，填完（或找不到封閉區域）自動關閉。只在主執行緒動。
 */
// profile-scope: device 只是「下一次點畫布要填色」的暫態，填完即清
object FillPickState {
    /** 填色用的麥克筆粗細（工具列的數字，經 `tool_base_width` 換成筆寬）。與 Apple 相同。 */
    const val BRUSH_SIZE = 1f

    var active by mutableStateOf(false)

    /** 最近一次填色的結果（填到了沒有、第幾次）。編輯器據此出提示；單頁與連續模式共用。 */
    var outcome by mutableStateOf<Pair<Boolean, Long>?>(null)
        private set

    /** 填完（或找不到封閉區域）：關閉填色並回報結果。 */
    fun finish(filled: Boolean) {
        active = false
        outcome = filled to System.nanoTime()
    }

    /** 這張紙的引導線（地圖輪廓、表格框線）當成填色邊界，見核心 `paper_fill_outlines`。 */
    fun paperOutlines(paperId: String): List<uniffi.padnote_core.FfiFillOutline> =
        runCatching { uniffi.padnote_core.paperFillOutlines(paperId, PageGeometry.width, PageGeometry.height) }
            .getOrDefault(emptyList())
}
