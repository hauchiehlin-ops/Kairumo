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
fun landObject(
    id: String, x: Float, y: Float, width: Float, height: Float, crossing: PageCrossing?
): PageLanding {
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
