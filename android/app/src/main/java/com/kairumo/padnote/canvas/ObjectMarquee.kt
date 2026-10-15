package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex

/**
 * 畫布物件的框選（Android）。
 *
 * 與 Apple 的 `ObjectMarquee` 同一套規則：
 *
 * - 框選是一個**明確的模式**，不是「在空白處拖曳」。打字模式下拖曳已經有
 *   兩個意思（拖物件＝搬它、拖空白＝捲畫布），再疊一個上去三者會互相搶。
 * - 判定用**相交**不是「完全包住」：使用者掃過一排卡片時，很少會把框拉得
 *   比那一排還大，要求完全包住的話十次有九次什麼都沒選到。
 * - 在選取範圍**裡面**開始拖＝整組搬移。
 */
data class MarqueeHit(
    val id: String,
    /** 頁面座標（點）。 */
    val x: Float,
    val y: Float,
    val width: Float,
    val height: Float
) {
    val rect: Rect get() = Rect(x, y, x + width, y + height)
}

object ObjectMarquee {

    /** 兩個角落拉出來的矩形。往左上拉也要成立。 */
    fun rect(start: Offset, end: Offset): Rect = Rect(
        minOf(start.x, end.x),
        minOf(start.y, end.y),
        maxOf(start.x, end.x),
        maxOf(start.y, end.y)
    )

    fun hits(box: Rect, candidates: List<MarqueeHit>): Set<String> {
        if (box.width <= 2f || box.height <= 2f) return emptySet()
        return candidates.filter { it.rect.overlaps(box) }.map { it.id }.toSet()
    }

    fun bounds(ids: Set<String>, candidates: List<MarqueeHit>): Rect? {
        val rects = candidates.filter { it.id in ids }.map { it.rect }
        if (rects.isEmpty()) return null
        return rects.drop(1).fold(rects.first()) { acc, r -> acc.expandToInclude(r) }
    }

    /**
     * 這一次拉框之後的選取。**連續框選**（[additive]）時新框到的加進原本的選取，不取代 ——
     * 散在頁面各處的物件可以一框一框累積起來。與 Apple 端 `ObjectMarquee.combined` 相同。
     */
    fun combined(existing: Set<String>, hits: Set<String>, additive: Boolean): Set<String> =
        if (additive) existing + hits else hits

    /**
     * 點一下的結果。點到物件：連續框選時切換它在不在選取裡；一般模式只選它。
     * 點到空白：一般模式取消選取；連續框選時保留（累積的選取不能因為手滑就沒了）。
     */
    fun tapped(id: String?, existing: Set<String>, additive: Boolean): Set<String> = when {
        id == null -> if (additive) existing else emptySet()
        !additive -> setOf(id)
        id in existing -> existing - id
        else -> existing + id
    }

    /** 點的位置上最上層的物件。候選依堆疊順序（由下到上）排列，所以從後面找。 */
    fun topmostHit(point: Offset, candidates: List<MarqueeHit>): String? =
        candidates.lastOrNull { it.rect.contains(point) }?.id

    /** 貼上／建立副本的位移。貼在原位的話使用者會以為沒成功。 */
    const val PASTE_OFFSET = 24f

    private fun Rect.expandToInclude(other: Rect) = Rect(
        minOf(left, other.left),
        minOf(top, other.top),
        maxOf(right, other.right),
        maxOf(bottom, other.bottom)
    )
}

/**
 * 框選圖層。
 *
 * @param candidates 這一頁上每個物件的位置與大小（頁面點）。
 * @param onCommitMove 整組搬移結束時回報位移（頁面點）。
 */
@Composable
fun MarqueeLayer(
    candidates: List<MarqueeHit>,
    density: Float,
    selectedIds: Set<String>,
    /** 連續框選：新框到、點到的物件加進選取，不取代。 */
    additive: Boolean = false,
    onSelectionChange: (Set<String>) -> Unit,
    onCommitMove: (Float, Float) -> Unit,
    modifier: Modifier = Modifier
) {
    var start by remember { mutableStateOf<Offset?>(null) }
    var current by remember { mutableStateOf<Offset?>(null) }
    var groupDrag by remember { mutableStateOf(Offset.Zero) }
    val selectionBounds = ObjectMarquee.bounds(selectedIds, candidates)

    Box(modifier.fillMaxSize().zIndex(9_000f)) {
        Box(
            Modifier
                .fillMaxSize()
                .pointerInput(candidates, selectedIds, additive) {
                    detectDragGestures(
                        onDragStart = { offset ->
                            // 座標進來是像素，物件是頁面點 —— 差一個 density。
                            val page = Offset(offset.x / density, offset.y / density)
                            if (selectionBounds != null && selectionBounds.contains(page)) {
                                groupDrag = Offset.Zero
                                start = null
                            } else {
                                start = page
                                current = page
                            }
                        },
                        onDrag = { change, drag ->
                            change.consume()
                            val d = Offset(drag.x / density, drag.y / density)
                            if (start == null) {
                                groupDrag += d
                            } else {
                                current = (current ?: start!!) + d
                            }
                        },
                        onDragEnd = {
                            val s = start
                            val c = current
                            if (s != null && c != null) {
                                onSelectionChange(
                                    ObjectMarquee.combined(
                                        selectedIds,
                                        ObjectMarquee.hits(ObjectMarquee.rect(s, c), candidates),
                                        additive
                                    )
                                )
                            } else if (groupDrag != Offset.Zero) {
                                onCommitMove(groupDrag.x, groupDrag.y)
                            }
                            start = null
                            current = null
                            groupDrag = Offset.Zero
                        },
                        onDragCancel = {
                            start = null; current = null; groupDrag = Offset.Zero
                        }
                    )
                }
                .pointerInput(candidates, selectedIds, additive) {
                    // 點物件＝選它（連續框選時切換加入／移除）；點空白＝取消選取（連續框選時保留）。
                    detectTapGestures { offset ->
                        val page = Offset(offset.x / density, offset.y / density)
                        onSelectionChange(
                            ObjectMarquee.tapped(ObjectMarquee.topmostHit(page, candidates), selectedIds, additive)
                        )
                    }
                }
        )

        // 每個被選中的物件各畫一個外框。只畫一個大框的話，
        // 使用者看不出「到底選到了哪幾個」。
        for (hit in candidates) {
            if (hit.id !in selectedIds) continue
            Box(
                Modifier
                    .offset {
                        IntOffset(
                            ((hit.x + groupDrag.x) * density).toInt(),
                            ((hit.y + groupDrag.y) * density).toInt()
                        )
                    }
                    .size(hit.width.dp, hit.height.dp)
                    .border(1.5.dp, MaterialTheme.colorScheme.primary)
            )
        }

        // 拉框中的橡皮筋
        val s = start
        val c = current
        if (s != null && c != null) {
            val box = ObjectMarquee.rect(s, c)
            Box(
                Modifier
                    .offset { IntOffset((box.left * density).toInt(), (box.top * density).toInt()) }
                    .size(box.width.dp, box.height.dp)
                    .background(MaterialTheme.colorScheme.primary.copy(alpha = 0.10f))
                    .border(1.dp, MaterialTheme.colorScheme.primary)
            )
        }
    }
}
