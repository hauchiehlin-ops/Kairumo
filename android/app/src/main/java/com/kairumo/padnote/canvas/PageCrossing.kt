package com.kairumo.padnote.canvas

import androidx.compose.runtime.staticCompositionLocalOf
import com.kairumo.padnote.ink.PageGeometry

/**
 * 連續模式裡，一頁的物件層拿到的「可以拖到別頁」資訊（單頁模式沒有，拖曳照舊夾在本頁）。
 *
 * 只靠夾回本頁的話，物件出不了它出生的那一頁：拖到下一頁、一放開又彈回原頁底邊。
 * 與 Apple 的 `PageCrossing` 對應；落點規則在核心（`landOnPage`），兩邊同一份。
 */
class PageCrossing(
    /** 這一層是第幾頁。 */
    val page: Int,
    val pageCount: Int,
    /** 頁與頁之間的間隔（頁面座標，dp）。 */
    val gap: Float,
    /** 開始拖曳：這一頁要畫在相鄰頁之上，拖過頁界時物件才不會被下一頁的紙蓋住。 */
    val began: () -> Unit,
    /** 這個物件能不能換頁（例如有連接線連到別的形狀、或在群組裡的就不行）。 */
    val canMove: (id: String) -> Boolean,
    /** 物件已經停在新位置（座標寫好、也存了），把它換到第 `to` 頁。 */
    val moved: (id: String, to: Int) -> Unit,
    /** 拖曳結束（不論有沒有換頁）。 */
    val ended: () -> Unit
)

val LocalPageCrossing = staticCompositionLocalOf<PageCrossing?> { null }

/** 拖曳放開的落點：新頁碼（沒換頁為 null）與那一頁裡的左上角。 */
data class PageLanding(val page: Int?, val x: Float, val y: Float)

/**
 * 物件 `id` 的外框 `(x, y, width, height)`（相對於它目前那一頁）放開後落在哪裡。
 * 沒有 `crossing`（單頁模式）或物件不能換頁時，等同 [PageGeometry.clampOrigin]。
 */
/**
 * 物件拖放的格線吸附（工具列「吸附格線」）。與 Apple `ObjectGridSnap` 同一條規則：
 * 格距來自核心 `pageSnapGrid`（從紙上真正畫出來的底紋推出）；空白紙上的物件不吸
 * （看不到的格子只會讓人對不準底下的 PDF），文字方塊另有自己的行線吸附。
 * 編輯器在開關切換、換紙時更新 [isEnabled] 與 [paperForPage]（主執行緒）。
 */
// profile-scope: device 工具列開關的鏡像與紙張格距快取，編輯器每次組合都重設
object ObjectGridSnap {
    @Volatile var isEnabled: Boolean = false
    /** 頁碼 → 紙張 id。`null` 是目前頁。 */
    @Volatile var paperForPage: (Int?) -> String = { "blank" }
    private val gridCache = java.util.concurrent.ConcurrentHashMap<String, uniffi.padnote_core.FfiSnapGrid>()
    private val texturedCache = java.util.concurrent.ConcurrentHashMap<String, Boolean>()

    private fun style(paper: String): uniffi.padnote_core.PageStyle =
        uniffi.padnote_core.paperTemplates().firstOrNull { it.id == paper }?.pageStyle
            ?: uniffi.padnote_core.PageStyle.BLANK

    fun grid(page: Int?): uniffi.padnote_core.FfiSnapGrid {
        val paper = paperForPage(page)
        val key = "$paper|${PageGeometry.width.toInt()}x${PageGeometry.height.toInt()}"
        return gridCache.getOrPut(key) {
            uniffi.padnote_core.pageSnapGrid(paper, style(paper), PageGeometry.width, PageGeometry.height)
        }
    }

    fun hasVisibleGrid(page: Int?): Boolean {
        val paper = paperForPage(page)
        return texturedCache.getOrPut(paper) {
            uniffi.padnote_core.pageTexture(paper, style(paper), PageGeometry.width, PageGeometry.height).isNotEmpty()
        }
    }

    fun snap(x: Float, y: Float, page: Int?): Pair<Float, Float> {
        if (!isEnabled || !runCatching { hasVisibleGrid(page) }.getOrDefault(false)) return x to y
        val p = runCatching { uniffi.padnote_core.snapOriginToGrid(x, y, grid(page)) }.getOrNull()
            ?: return x to y
        return p.x to p.y
    }
}

fun landObject(
    id: String, x0: Float, y0: Float, width: Float, height: Float, crossing: PageCrossing?
): PageLanding {
    // 「吸附格線」開著：先吸到紙上的格子，再夾回可列印範圍。所有物件拖放都經過這裡。
    val (x, y) = ObjectGridSnap.snap(x0, y0, crossing?.page)
    if (crossing != null) {
        val landing = runCatching {
            uniffi.padnote_core.landOnPage(
                uniffi.padnote_core.FfiRect(x, y, x + width, y + height),
                crossing.page.coerceAtLeast(0).toUInt(),
                crossing.pageCount.coerceAtLeast(1).toUInt(),
                PageGeometry.width,
                PageGeometry.height,
                crossing.gap,
                PageGeometry.PRINTABLE_INSET
            )
        }.getOrNull()
        if (landing != null) {
            val target = landing.pageIndex.toInt()
            if (target == crossing.page) return PageLanding(null, landing.minX, landing.minY)
            if (crossing.canMove(id)) return PageLanding(target, landing.minX, landing.minY)
        }
    }
    val clamped = PageGeometry.clampOrigin(x, y, width, height)
    return PageLanding(null, clamped.first, clamped.second)
}
