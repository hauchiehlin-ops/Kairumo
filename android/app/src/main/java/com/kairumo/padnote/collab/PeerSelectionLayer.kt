package com.kairumo.padnote.collab

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.kairumo.padnote.LocalizationStrings
import com.kairumo.padnote.canvas.MarqueeHit
import kotlinx.coroutines.delay

/**
 * 別人正在編輯（或打字）的物件：畫上對方顏色的外框與名字（設計 §5 規則 2）。
 *
 * 與 Apple 端物件上的協作外框同一個意思：看得到「誰在動哪一個」，就不會兩個人同時去改同一個物件。
 * 這一層不吃觸控 —— 只是標記；真正擋住編輯的是選取時的租約檢查。
 *
 * @param frames 這一頁所有物件的外框（頁面座標，與框選共用同一份）。
 */
@Composable
fun PeerSelectionLayer(frames: List<MarqueeHit>, manager: CollaborationManager, languageTag: String) {
    // 租約 5 秒沒續就失效：每秒重畫一次，對方放手或斷線後外框自己消失。
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        while (true) {
            delay(1_000)
            tick++
        }
    }
    val now = remember(tick) { System.currentTimeMillis() }
    val byId = frames.associateBy { AndroidCollabCanvas.canonicalId(it.id) }
    for (peer in manager.peers) {
        val selected = peer.selectedId ?: continue
        if (now - peer.lastActiveMs >= CollaborationManager.LEASE_TIMEOUT_MS) continue
        val typing = selected.startsWith(CollaborationManager.TYPING_PREFIX)
        val frame = byId[selected.removePrefix(CollaborationManager.TYPING_PREFIX)] ?: continue
        val color = runCatching { Color(android.graphics.Color.parseColor(peer.userColor)) }.getOrDefault(Color.Gray)
        val label = LocalizationStrings.localized(if (typing) "collab_peer_typing" else "collab_object_locked", languageTag)
            .replace("%@", peer.userName)
        Box(
            Modifier
                .offset(x = (frame.x - 3f).dp, y = (frame.y - 3f).dp)
                .size(width = (frame.width + 6f).dp, height = (frame.height + 6f).dp)
                .border(2.dp, color, RoundedCornerShape(6.dp))
                .zIndex(Float.MAX_VALUE)
        )
        Text(
            label,
            color = Color.White,
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier
                .offset(x = (frame.x - 3f).dp, y = (frame.y - 22f).dp)
                .zIndex(Float.MAX_VALUE)
                .background(color, RoundedCornerShape(4.dp))
                .padding(horizontal = 6.dp, vertical = 1.dp)
        )
    }
}
