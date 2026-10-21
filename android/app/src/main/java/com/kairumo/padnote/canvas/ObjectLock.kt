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

/**
 * 鎖定在畫布上（與 Apple 的 `ObjectLockActions`／`canvasLocked` 同一套規則）。
 *
 * # 為什麼要有
 *
 * 雙指縮放或捲動頁面時，第一根手指常常落在某個物件上：它先被選起來、被拖動，
 * 甚至進入編輯，第二根手指才到。鎖定的物件**完全不接收觸控**（點選、拖曳都穿透到頁面），
 * 所以兩指操作頁面時再怎麼碰到它都不會動。
 *
 * # 存在哪裡
 *
 * 筆記本中繼資料的 `lockedObjectIdsByPage`（`NotebookMeta.KEY_LOCKED_BY_PAGE`），
 * 與「移到筆跡下方」同一條路：一份每頁一張的物件 id 名單，兩個平台讀寫同一組鍵，
 * 不必在九種物件各自的格式裡加欄位。
 *
 * # 怎麼解除（看得到就要點得到）
 *
 * 鎖定的物件本身不接觸控，它自己的選單也就打不開，所以另外給三個入口：
 * 打字模式下點物件角落的鎖頭（[LockBadges]）、或單指點一下鎖定的物件（穿透到頁面的那一下由
 * 編輯器用 [lockedObjectHit] 接住，不會在那裡開新文字方塊），物件上方就出現「解除鎖定」鈕
 * （[UnlockPrompt]）；另外圖層面板每一列都有鎖頭開關。鎖上則從物件的層級選單或圖層面板。
 */
data class ObjectLockActions(
    val isLocked: (String) -> Boolean,
    val setLocked: (String, Boolean) -> Unit
)

/** 由編輯器提供。沒有提供時（預覽、測試）鎖定的選項不出現。 */
val LocalObjectLock = compositionLocalOf<ObjectLockActions?> { null }

/** 這一頁鎖定的物件 id。各物件層據此把該物件的 `interactive` 關掉，觸控就穿透過去。 */
val LocalLockedObjectIds = compositionLocalOf<Set<String>> { emptySet() }

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
 * 鎖定物件右上角的鎖頭（打字／物件模式才畫 —— 手寫模式下物件本來就不接觸控）。
 *
 * **點得到**：看得到的鎖定物件一定要就地點得到解鎖的入口。點鎖頭呼叫 [onTap]，由編輯器在
 * 物件上方放「解除鎖定」鈕（[UnlockPrompt]）。鎖頭只吃單指點擊；雙指縮放、捲動由外層在
 * Initial 階段先接走，碰到鎖頭也照樣縮放。座標是頁面點（＝dp）。
 */
@Composable
fun LockBadges(
    frames: List<MarqueeHit>,
    lockedIds: Set<String>,
    label: String,
    onTap: (String) -> Unit
) {
    for (frame in frames) {
        if (frame.id !in lockedIds) continue
        Box(
            modifier = Modifier
                .zIndex(9_500f)
                .offset((frame.x + frame.width - 16f).dp, (frame.y - 16f).dp)
                .size(32.dp)
                .clickable { onTap(frame.id) }
                .semantics { contentDescription = label },
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier.background(Color(0xE6F59E0B), CircleShape).padding(horizontal = 5.dp, vertical = 3.dp)
            ) { Text("🔒", fontSize = 10.sp) }
        }
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
