package com.kairumo.padnote.canvas

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.kairumo.padnote.LocalizationStrings
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

/**
 * 畫布上**所有**物件的堆疊面板（Android）。
 *
 * 與 Apple 端的 `CanvasStackPanel` 對齊：同一組規則（`ObjectStacking`）、
 * 同一組在地化鍵、同樣「由上到下＝由前到後」的排列 —— 那是圖層面板的慣例，
 * 反過來的話使用者每按一次「上移」都要在腦中翻譯一次。
 *
 * 既有的 `shape.LayerPanel` 只認形狀。這一個認五種型別，改的是筆記本中繼
 * 資料裡的 `objectOrderByPage`，所以順序跨得過平台。
 */
@Composable
fun CanvasStackPanel(
    items: List<ObjectStacking.Item>,
    order: List<String>,
    underInkIds: Set<String> = emptySet(),
    /** 鎖定在畫布上的物件（見 ObjectLock.kt）。鎖定的物件在畫布上點不到，解除鎖定就靠這個面板。 */
    lockedIds: Set<String> = emptySet(),
    onLockChange: ((String, Boolean) -> Unit)? = null,
    languageTag: String,
    onOrderChange: (List<String>) -> Unit,
    onUnderInkChange: ((Set<String>) -> Unit)? = null,
    /**
     * 對齊指定的那些物件。
     *
     * 選取清單由這個面板持有 —— 畫布上的選取是「每種型別各一個」，
     * 兩個文字方塊根本選不起來，而對齊最常用的就是那種情況。
     */
    onAlign: (uniffi.padnote_core.FfiAlignMode, List<String>) -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("layerPanel", 280.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var selection by remember { mutableStateOf(setOf<String>()) }
    val byId = remember(items) { items.associateBy { it.id } }
    // 由上到下＝由前到後。
    val rows = remember(order, items) { order.mapNotNull { byId[it] }.reversed() }

    fun apply(op: (Set<String>, List<String>) -> List<String>) {
        if (selection.isEmpty()) return
        onOrderChange(op(selection, order))
    }

    fun sendToBack() {
        if (selection.isEmpty()) return
        // 置底時，若有支援 underInkChange 則自動置於筆跡下方
        if (onUnderInkChange != null) {
            val updated = underInkIds + selection
            onUnderInkChange(updated)
        }
        onOrderChange(ObjectStacking.sendToBack(selection, order))
    }

    fun bringToFront() {
        if (selection.isEmpty()) return
        // 置頂時，自動自筆跡下方移除（置於筆跡上方）
        if (onUnderInkChange != null) {
            val updated = underInkIds - selection
            onUnderInkChange(updated)
        }
        onOrderChange(ObjectStacking.bringToFront(selection, order))
    }

    fun toggleBelowInk() {
        if (selection.isEmpty() || onUnderInkChange == null) return
        val allBelow = selection.all { it in underInkIds }
        val updated = if (allBelow) {
            underInkIds - selection
        } else {
            underInkIds + selection
        }
        onUnderInkChange(updated)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("layers_panel")) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (rows.isEmpty()) {
                    Text(l("layers_empty"), style = MaterialTheme.typography.bodySmall)
                } else {
                    Text(l("layers_hint"), style = MaterialTheme.typography.labelSmall)
                    Column(
                        modifier = Modifier.height(height.value).verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        for (item in rows) {
                            val picked = item.id in selection
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(
                                        if (picked) MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                                        else Color.Transparent,
                                        RoundedCornerShape(6.dp)
                                    )
                                    .clickable {
                                        selection = if (picked) selection - item.id
                                        else selection + item.id
                                    }
                                    .padding(horizontal = 8.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(8.dp)
                            ) {
                                val isBelowInk = item.id in underInkIds
                                Text(item.kind.mark(), style = MaterialTheme.typography.labelMedium)
                                Text(
                                    item.title,
                                    style = MaterialTheme.typography.bodySmall,
                                    maxLines = 1,
                                    modifier = Modifier.weight(1f)
                                )
                                if (isBelowInk) {
                                    Text(
                                        "[" + l("layer_send_below_ink") + "]",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.tertiary
                                    )
                                }
                                if (picked) Text("✓", fontWeight = FontWeight.Bold)
                                if (onLockChange != null) {
                                    val locked = item.id in lockedIds
                                    Text(
                                        if (locked) "🔒" else "🔓",
                                        color = if (locked) Color(0xFFF59E0B) else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                                        modifier = Modifier
                                            .clickable { onLockChange(item.id, !locked) }
                                            .padding(horizontal = 4.dp)
                                            .semantics {
                                                contentDescription = l(if (locked) "object_unlock" else "object_lock")
                                            }
                                    )
                                }
                            }
                        }
                    }
                    // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
                    // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
                    DialogResizeHandle(height, "layerPanel")

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        TextButton(onClick = { sendToBack() }, enabled = selection.isNotEmpty()) { Text("⤓") }
                        TextButton(onClick = { apply(ObjectStacking::sendBackward) }, enabled = selection.isNotEmpty()) { Text("↓") }
                        TextButton(onClick = { apply(ObjectStacking::bringForward) }, enabled = selection.isNotEmpty()) { Text("↑") }
                        TextButton(onClick = { bringToFront() }, enabled = selection.isNotEmpty()) { Text("⤒") }
                        if (onUnderInkChange != null) {
                            val allBelow = selection.isNotEmpty() && selection.all { it in underInkIds }
                            TextButton(
                                onClick = { toggleBelowInk() },
                                enabled = selection.isNotEmpty()
                            ) {
                                Text(
                                    if (allBelow) l("layer_bring_above_ink") else l("layer_send_below_ink"),
                                    style = MaterialTheme.typography.labelSmall
                                )
                            }
                        }
                    }

                    Text(l("align_objects"), style = MaterialTheme.typography.labelSmall)
                    // 兩列四個。八個排成一列在手機寬度上每個只剩一點點。
                    for (row in ALIGN_MODES.chunked(4)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            for ((mode, mark) in row) {
                                TextButton(
                                    // 照目前的堆疊順序傳，讓兩邊拿到一致的次序。
                                    onClick = { onAlign(mode, order.filter { it in selection }) },
                                    enabled = selection.size >= 2
                                ) { Text(mark) }
                            }
                        }
                    }
                    if (selection.size < 2) {
                        // 只選一個時按鈕是停用的 —— 不說原因的話使用者以為壞了。
                        Text(
                            l("align_needs_two"),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("close")) } }
    )
}

/**
 * 對齊方式與它的符號。**順序與 Apple 端的 `ObjectAlignment.modes` 相同** ——
 * 兩邊按鈕排列不同的話，使用者換裝置就要重新找哪一顆是靠左。
 */
private val ALIGN_MODES = listOf(
    uniffi.padnote_core.FfiAlignMode.LEFT to "⇤",
    uniffi.padnote_core.FfiAlignMode.HORIZONTAL_CENTER to "⇔",
    uniffi.padnote_core.FfiAlignMode.RIGHT to "⇥",
    uniffi.padnote_core.FfiAlignMode.TOP to "⤒",
    uniffi.padnote_core.FfiAlignMode.VERTICAL_MIDDLE to "⇕",
    uniffi.padnote_core.FfiAlignMode.BOTTOM to "⤓",
    uniffi.padnote_core.FfiAlignMode.DISTRIBUTE_HORIZONTALLY to "⋯",
    uniffi.padnote_core.FfiAlignMode.DISTRIBUTE_VERTICALLY to "⋮"
)

/**
 * 型別的視覺標記。
 *
 * 用文字符號而不是 Material icon：那要多拉一組相依，而這裡只需要
 * 「一眼分得出是哪一種」。
 */
private fun ObjectStacking.Kind.mark(): String = when (this) {
    ObjectStacking.Kind.IMAGE -> "▣"
    ObjectStacking.Kind.SHAPE -> "◇"
    ObjectStacking.Kind.TABLE -> "▦"
    ObjectStacking.Kind.CHART -> "▥"
    ObjectStacking.Kind.MODEL3D -> "◈"
    ObjectStacking.Kind.LINK -> "⛓"
    ObjectStacking.Kind.AUDIO -> "♪"
    ObjectStacking.Kind.TEXT -> "T"
    ObjectStacking.Kind.PIN -> "◉"
}
