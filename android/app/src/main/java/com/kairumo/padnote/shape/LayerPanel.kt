package com.kairumo.padnote.shape

import androidx.compose.foundation.layout.height
import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.background
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
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings

/**
 * 圖層面板（Android）。
 *
 * 與 Apple 的 `ObjectLayerPanel` 對齊：同一組規則（`ObjectLayer`）、同一組
 * 在地化鍵、同樣「由上到下＝由前到後」的排列。
 *
 * 核心的物件樹一直都有堆疊與群組操作，但兩個平台的介面只做到選取與搬動 ——
 * 使用者碰得到物件，卻碰不到它們的順序。兩個方塊疊在一起時沒有任何辦法把
 * 下面那個拉上來。
 */
@Composable
fun LayerPanel(
    shapes: List<NoteShape>,
    selection: Set<String>,
    languageTag: String,
    onSelectionChange: (Set<String>) -> Unit,
    onShapesChange: (List<NoteShape>) -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("shapeLayers", 220.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    val rows = ObjectLayer.rows(
        shapes,
        unnamed = l("layer_unnamed"),
        groupLabel = { count -> l("layer_group_name").replace("%@", "$count") }
    )

    // 依目前的堆疊順序排好的選取項。
    //
    // 不排的話，多選時的搬移結果會取決於 Set 的迭代順序 ——
    // 同樣的操作每次得到的順序都不一樣。
    val orderedSelection = shapes.map { it.id }.filter { it in selection }

    fun reorder(op: (String, List<NoteShape>) -> List<NoteShape>) {
        var next = shapes
        // 整組一起動：群組裡的成員不能被拆散在不同的層裡，
        // 否則別的東西會夾在它們中間。
        for (id in orderedSelection) next = op(id, next)
        onShapesChange(next)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("layers_panel")) },
        confirmButton = { TextButton(onClick = onDismiss) { Text(l("close")) } },
        text = {
            if (shapes.isEmpty()) {
                Text(l("layers_empty"), style = MaterialTheme.typography.bodySmall)
                return@AlertDialog
            }
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    l("layers_hint"),
                    fontSize = 10.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                Column(
                    Modifier.height(height.value).verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    for (row in rows) {
                        val ids = if (row.isGroup) {
                            shapes.filter { it.groupId == row.id }.map { it.id }.toSet()
                        } else {
                            setOf(row.id)
                        }
                        val isSelected = ids.isNotEmpty() && selection.containsAll(ids)
                        TextButton(
                            onClick = {
                                // 選群組＝選它的全部成員。只選群組本身的話，
                                // 接下來每個操作都得再判斷一次「這是群組還是形狀」。
                                onSelectionChange(
                                    if (isSelected) selection - ids else selection + ids
                                )
                            },
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(
                                    if (isSelected) {
                                        MaterialTheme.colorScheme.primary.copy(alpha = 0.12f)
                                    } else {
                                        androidx.compose.ui.graphics.Color.Transparent
                                    },
                                    RoundedCornerShape(6.dp)
                                )
                        ) {
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    if (row.isGroup) "▣" else "▢",
                                    modifier = Modifier.padding(end = 6.dp)
                                )
                                Text(row.label, fontSize = 12.sp, maxLines = 1)
                            }
                        }
                    }
                }
                // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
                // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
                DialogResizeHandle(height, "shapeLayers")

                HorizontalDivider()

                Row(Modifier.fillMaxWidth(), Arrangement.SpaceEvenly) {
                    TextButton(
                        onClick = { reorder(ObjectLayer::sendToBack) },
                        enabled = selection.isNotEmpty()
                    ) { Text("⤓", fontSize = 16.sp) }
                    TextButton(
                        onClick = { reorder(ObjectLayer::sendBackward) },
                        enabled = selection.isNotEmpty()
                    ) { Text("↓", fontSize = 16.sp) }
                    TextButton(
                        onClick = { reorder(ObjectLayer::bringForward) },
                        enabled = selection.isNotEmpty()
                    ) { Text("↑", fontSize = 16.sp) }
                    TextButton(
                        onClick = { reorder(ObjectLayer::bringToFront) },
                        enabled = selection.isNotEmpty()
                    ) { Text("⤒", fontSize = 16.sp) }
                }

                Row(Modifier.fillMaxWidth(), Arrangement.SpaceEvenly) {
                    TextButton(
                        onClick = { onShapesChange(ObjectLayer.group(selection, shapes).first) },
                        enabled = selection.size >= 2
                    ) { Text(l("layer_group"), fontSize = 12.sp) }

                    val selectedGroups = shapes
                        .filter { it.id in selection }
                        .mapNotNull { it.groupId }
                        .toSet()
                    TextButton(
                        onClick = {
                            var next = shapes
                            for (groupId in selectedGroups) next = ObjectLayer.ungroup(groupId, next)
                            onShapesChange(next)
                        },
                        enabled = selectedGroups.isNotEmpty()
                    ) { Text(l("layer_ungroup"), fontSize = 12.sp) }
                }

                if (selection.size < 2) {
                    Text(
                        l("layer_select_two"),
                        fontSize = 10.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    )
}
