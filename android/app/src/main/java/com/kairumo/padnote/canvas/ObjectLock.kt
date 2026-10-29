package com.kairumo.padnote.canvas

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.Alignment
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.PointerType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown

/**
 * 鎖定在畫布上（與 Apple 的 `ObjectLockActions`／`canvasLocked` 同一套規則）。
 *
 * # 為什麼要有
 *
 * 雙指縮放或捲動頁面時，第一根手指常常落在某個物件上，物件就被拖走了。鎖定的物件
 * **只鎖位置與外形**：不能拖曳、縮放、旋轉（拖過它就是捲動頁面），兩指操作頁面時再怎麼
 * 碰到它都不會動。點選、編輯內容（文字、表格、圖表、樣式面板）、層級選單都照常 ——
 * 鎖定是為了不被誤觸搬走，不是把物件凍結起來（以前是整個不接觸控，表格就改不了內容）。
 *
 * # 存在哪裡
 *
 * 筆記本中繼資料的 `lockedObjectIdsByPage`（`NotebookMeta.KEY_LOCKED_BY_PAGE`），
 * 與「移到筆跡下方」同一條路：一份每頁一張的物件 id 名單，兩個平台讀寫同一組鍵，
 * 不必在九種物件各自的格式裡加欄位。
 *
 * # 怎麼解除（看得到就要點得到）
 *
 * 物件自己的層級選單（[OrderHandle]）裡就有「解除鎖定」。另外：
 * 打字模式下點物件角落的鎖頭（[LockBadges]），物件上方就出現「解除鎖定」鈕
 * （[UnlockPrompt]）；手寫模式下鎖頭照樣畫，手指點一下鎖定的物件（[fingerTapOnLockedObject]）
 * 就切到打字模式並給出同一顆鈕；另外圖層面板每一列都有鎖頭開關。鎖上則從物件的層級選單或圖層面板。
 */
data class ObjectLockActions(
    val isLocked: (String) -> Boolean,
    val setLocked: (String, Boolean) -> Unit
)

/** 由編輯器提供。沒有提供時（預覽、測試）鎖定的選項不出現。 */
val LocalObjectLock = compositionLocalOf<ObjectLockActions?> { null }

/** 這一頁鎖定的物件 id。各物件據此（[isMoveLocked]）關掉搬移、縮放與旋轉。 */
val LocalLockedObjectIds = compositionLocalOf<Set<String>> { emptySet() }

/**
 * 這個物件鎖定在畫布上：關掉它的拖曳手勢、縮放與旋轉把手，其餘互動照常。
 * 與 Apple 端的 `canvasObjectLocked` 同一條規則。
 */
@Composable
fun isMoveLocked(id: String): Boolean = id in LocalLockedObjectIds.current

/**
 * 這一頁移到筆跡下方的物件 id。只用來認出「底稿」：鎖定、在筆跡下方、又撐滿頁寬或頁高的圖片
 * （匯入的 PDF 頁面就是這樣放的）照舊不接觸控，點它是要在上面寫字、打字，不是選取那張整頁的圖。
 */
val LocalUnderInkObjectIds = compositionLocalOf<Set<String>> { emptySet() }

/** 點在哪一個鎖定物件上（`frames` 由下到上排，取最上面那一個）。放寬一圈，點角落的鎖頭也算。 */
fun lockedObjectHit(x: Float, y: Float, frames: List<MarqueeHit>, lockedIds: Set<String>): String? {
    if (lockedIds.isEmpty()) return null
    val pad = 20f
    return frames.lastOrNull { f ->
        f.id in lockedIds && x >= f.x - pad && x <= f.x + f.width + pad &&
            y >= f.y - pad && y <= f.y + f.height + pad
    }?.id
}

/**
 * 打字模式點頁面時的鎖定判定：只有點在鎖定物件的**外圍**（角落的鎖頭露在物件外面）才算，
 * 回傳該物件 id。點在物件本身上回 null —— 鎖定只鎖位置，那一下照常處理
 * （物件自己會接住；底稿圖片不接觸控，那一下就是在頁面上打字）。
 */
fun lockedObjectRimHit(x: Float, y: Float, frames: List<MarqueeHit>, lockedIds: Set<String>): String? {
    val id = lockedObjectHit(x, y, frames, lockedIds) ?: return null
    val f = frames.lastOrNull { it.id == id } ?: return null
    val inside = x >= f.x && x <= f.x + f.width && y >= f.y && y <= f.y + f.height
    return if (inside) null else id
}

/**
 * 鎖定物件右上角的鎖頭。兩種模式都畫：手寫模式下看不出物件鎖住了，使用者只會以為它壞了。
 *
 * **點得到**：看得到的鎖定物件一定要就地點得到解鎖的入口。打字模式下點鎖頭呼叫 [onTap]，由編輯器在
 * 物件上方放「解除鎖定」鈕（[UnlockPrompt]）。鎖頭只吃單指點擊；雙指縮放、捲動由外層在
 * Initial 階段先接走，碰到鎖頭也照樣縮放。座標是頁面點（＝dp）。
 *
 * 手寫模式傳 `onTap = null`：鎖頭只顯示、不接觸控，筆從鎖頭上落下照樣寫得出來。
 * 那時的入口是 [fingerTapOnLockedObject]（它的判定範圍放寬 20dp，涵蓋鎖頭）。
 */
@Composable
fun LockBadges(
    frames: List<MarqueeHit>,
    lockedIds: Set<String>,
    label: String,
    onTap: ((String) -> Unit)?
) {
    for (frame in frames) {
        if (frame.id !in lockedIds) continue
        Box(
            modifier = Modifier
                .zIndex(9_500f)
                .offset((frame.x + frame.width - 16f).dp, (frame.y - 16f).dp)
                .size(32.dp)
                .then(if (onTap != null) Modifier.clickable { onTap(frame.id) } else Modifier)
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier.background(Color(0xE6F59E0B), CircleShape).padding(horizontal = 5.dp, vertical = 3.dp)
            ) { Text("🔒", fontSize = 10.sp) }
        }
    }
}

/** 手指點擊的時間上限：比飛梭工具盤的長按（0.55 秒）短，兩者不會同時成立。 */
private const val LOCK_TAP_MILLIS = 400L

/**
 * 手寫模式下的解鎖入口：**手指**單擊鎖定的物件（或它的鎖頭），呼叫 [onTap] 帶物件 id。
 * 編輯器據此切到打字模式並放出「解除鎖定」鈕 —— 與 Apple 端 `handleCanvasDirectTap`
 * 手寫分支一致。
 *
 * 掛在畫布（[InkCanvas] 的父層）上，在 Initial 階段旁觀，不擋其他手勢：
 * - 只看手指；筆尖一律照常書寫。
 * - 落點不在鎖定物件上、第二指落下、移動超過觸控門檻、按太久，就放手不管 ——
 *   一指畫線、雙指縮放捲動、長按飛梭工具盤都照舊。
 * - 成立時（手指在原處抬起）先 [onCancelInk] 取消正在進行的那一筆，再把抬起事件吃掉，
 *   畫布收到的是取消而不是收筆，紙上不會留下墨點。
 *
 * [hitAt] 收的是這個 Modifier 所在節點的本地座標（px），回傳鎖定物件 id 或 null；
 * 手寫模式以外請讓它回 null。
 */
fun Modifier.fingerTapOnLockedObject(
    key: Any?,
    hitAt: (Offset) -> String?,
    onCancelInk: () -> Unit,
    onTap: (String) -> Unit
): Modifier = pointerInput(key) {
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        if (down.type != PointerType.Touch) return@awaitEachGesture
        val hit = hitAt(down.position) ?: return@awaitEachGesture
        val slop = viewConfiguration.touchSlop
        var released: PointerInputChange? = null
        withTimeoutOrNull(LOCK_TAP_MILLIS) {
            while (released == null) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val tracked = event.changes.firstOrNull { it.id == down.id } ?: break
                if (event.changes.count { it.pressed } > 1) break
                if ((tracked.position - down.position).getDistance() > slop) break
                if (!tracked.pressed) released = tracked
            }
        }
        val up = released ?: return@awaitEachGesture
        onCancelInk()
        up.consume()
        onTap(hit)
    }
}

/** 鎖定物件上方的「解除鎖定」鈕（頁面點）。點下去就解鎖，物件立刻可以選取、搬動。 */
@Composable
fun UnlockPrompt(frame: MarqueeHit, label: String, onUnlock: () -> Unit) {
    Box(
        modifier = Modifier
            .zIndex(9_800f)
            .offset((frame.x + frame.width / 2f - 56f).dp, maxOf(4f, frame.y - 40f).dp)
            .background(Color(0xFFF59E0B), RoundedCornerShape(50))
            .clickable { onUnlock() }
            .padding(horizontal = 12.dp, vertical = 6.dp)
            .testTag("object.unlock.prompt")
    ) {
        Text("🔓 $label", color = Color.White, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** 兩次輕點之間的最長間隔（毫秒）。 */
private const val DOUBLE_TAP_MILLIS = 350L

/**
 * 手寫模式下**手指雙擊**空白處：呼叫 [onDoubleTap]（本地座標 px）。
 *
 * 和 [fingerTapOnLockedObject] 一樣在 Initial 階段旁觀、不擋其他手勢；只看手指，
 * 筆尖照常書寫。成立時（第二下在原處抬起）先 [onCancelInk] 取消進行中的那一筆，
 * 再把抬起事件吃掉。第一下輕點照舊是一般的點，不受影響。
 */
fun Modifier.fingerDoubleTap(
    key: Any?,
    hitAt: (Offset) -> Boolean,
    onCancelInk: () -> Unit,
    onDoubleTap: (Offset) -> Unit
): Modifier = pointerInput(key) {
    var lastTapTime = 0L
    var lastTapPos = Offset.Zero
    awaitEachGesture {
        val down = awaitFirstDown(requireUnconsumed = false, pass = PointerEventPass.Initial)
        if (down.type != PointerType.Touch || !hitAt(down.position)) {
            lastTapTime = 0L
            return@awaitEachGesture
        }
        val slop = viewConfiguration.touchSlop
        var released: PointerInputChange? = null
        withTimeoutOrNull(LOCK_TAP_MILLIS) {
            while (released == null) {
                val event = awaitPointerEvent(PointerEventPass.Initial)
                val tracked = event.changes.firstOrNull { it.id == down.id } ?: break
                if (event.changes.count { it.pressed } > 1) break
                if ((tracked.position - down.position).getDistance() > slop) break
                if (!tracked.pressed) released = tracked
            }
        }
        val up = released
        if (up == null) {
            lastTapTime = 0L
            return@awaitEachGesture
        }
        val now = up.uptimeMillis
        val isSecond = lastTapTime != 0L && now - lastTapTime <= DOUBLE_TAP_MILLIS &&
            (up.position - lastTapPos).getDistance() <= slop * 6f
        if (isSecond) {
            lastTapTime = 0L
            onCancelInk()
            up.consume()
            onDoubleTap(up.position)
        } else {
            lastTapTime = now
            lastTapPos = up.position
        }
    }
}
