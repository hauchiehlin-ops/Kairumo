package com.kairumo.padnote.canvas

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
    languageTag: String,
    onOrderChange: (List<String>) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    var selection by remember { mutableStateOf(setOf<String>()) }
    val byId = remember(items) { items.associateBy { it.id } }
    // 由上到下＝由前到後。
    val rows = remember(order, items) { order.mapNotNull { byId[it] }.reversed() }

    fun apply(op: (Set<String>, List<String>) -> List<String>) {
        if (selection.isEmpty()) return
        onOrderChange(op(selection, order))
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
                        modifier = Modifier.heightIn(max = 280.dp).verticalScroll(rememberScrollState()),
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
                                Text(item.kind.mark(), style = MaterialTheme.typography.labelMedium)
                                Text(
                                    item.title,
                                    style = MaterialTheme.typography.bodySmall,
                                    maxLines = 1,
                                    modifier = Modifier.weight(1f)
                                )
                                if (picked) Text("✓", fontWeight = FontWeight.Bold)
                            }
                        }
                    }

                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        TextButton(onClick = { apply(ObjectStacking::sendToBack) }) { Text("⤓") }
                        TextButton(onClick = { apply(ObjectStacking::sendBackward) }) { Text("↓") }
                        TextButton(onClick = { apply(ObjectStacking::bringForward) }) { Text("↑") }
                        TextButton(onClick = { apply(ObjectStacking::bringToFront) }) { Text("⤒") }
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("close")) } }
    )
}

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
    ObjectStacking.Kind.TEXT -> "T"
    ObjectStacking.Kind.PIN -> "◉"
}
