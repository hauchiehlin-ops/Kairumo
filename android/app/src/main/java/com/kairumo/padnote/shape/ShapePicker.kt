package com.kairumo.padnote.shape

import com.kairumo.padnote.ui.DialogResizeHandle
import com.kairumo.padnote.ui.rememberDialogHeight
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import uniffi.padnote_core.FfiRect
import uniffi.padnote_core.FfiShape
import uniffi.padnote_core.FfiShapeKind
import uniffi.padnote_core.allShapeKinds
import uniffi.padnote_core.flowchartShapeKinds
import uniffi.padnote_core.flowchartTemplates
import uniffi.padnote_core.shapeArrowHeads
import uniffi.padnote_core.shapeIsLinear
import uniffi.padnote_core.shapeOutline
import uniffi.padnote_core.shapeSemantic

/**
 * 形狀挑選面板（Android）。
 *
 * 一般形狀、ISO 5807 流程圖符號、內建範本 —— 與 Apple 的 `ShapeStudioView`
 * 同一組內容與同一組在地化鍵。
 */
@Composable
fun ShapePicker(
    languageTag: String,
    onCommit: (List<NoteShape>, List<NoteConnection>) -> Unit,
    onDismiss: () -> Unit
) {
    val height = rememberDialogHeight("shapePicker", 420.dp)

    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("shape_studio")) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } },
        text = {
            Column(
                Modifier.height(height.value).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(l("shape_section_basic"), style = MaterialTheme.typography.titleSmall)
                KindGrid(
                    allShapeKinds().filter { it !in flowchartShapeKinds() },
                    languageTag
                ) { kind ->
                    onCommit(listOf(NoteShape(kindName = NoteShape.nameOf(kind))), emptyList())
                }

                HorizontalDivider()
                Text(l("shape_section_flowchart"), style = MaterialTheme.typography.titleSmall)
                KindGrid(flowchartShapeKinds(), languageTag) { kind ->
                    onCommit(listOf(NoteShape(kindName = NoteShape.nameOf(kind))), emptyList())
                }

                HorizontalDivider()
                Text(l("shape_section_templates"), style = MaterialTheme.typography.titleSmall)
                for (template in flowchartTemplates()) {
                    TextButton(onClick = {
                        val (shapes, connections) = insert(template)
                        onCommit(shapes, connections)
                    }) {
                        Column(Modifier.fillMaxWidth()) {
                            Text(template.id)
                            Text(
                                l("shape_node_count").replace("%@", "${template.nodes.size}"),
                                fontSize = 10.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
            // 底部的拖曳把手：往下拖變高。放在捲動容器**外面** ——
            // 放進去的話把手會跟著內容捲走，捲到一半就再也找不到它。
            DialogResizeHandle(height, "shapePicker")
        }
    )
}

/**
 * 把一份範本展開成形狀與連線。
 *
 * 節點與連接線一起給出去 —— 只給節點的話，使用者得自己一條一條連，
 * 那範本就沒有意義了。
 */
private fun insert(template: uniffi.padnote_core.FfiTemplate):
    Pair<List<NoteShape>, List<NoteConnection>> {
    val originX = 60f
    val originY = 140f
    val shapes = template.nodes.map { node ->
        NoteShape(
            kindName = NoteShape.nameOf(node.kind),
            x = originX + node.bounds.minX,
            y = originY + node.bounds.minY,
            width = node.bounds.maxX - node.bounds.minX,
            height = node.bounds.maxY - node.bounds.minY,
            label = node.label
        )
    }
    val connections = template.edges.mapNotNull { edge ->
        val from = shapes.getOrNull(edge.from.toInt()) ?: return@mapNotNull null
        val to = shapes.getOrNull(edge.to.toInt()) ?: return@mapNotNull null
        NoteConnection(fromShapeId = from.id, toShapeId = to.id, label = edge.label)
    }
    return shapes to connections
}

@Composable
private fun KindGrid(
    kinds: List<FfiShapeKind>,
    languageTag: String,
    onPick: (FfiShapeKind) -> Unit
) {
    // **格子刻意做小。** 這裡的圖只是「這是什麼形狀」的示意，不是預覽 ——
    // 一格 84dp 的話，五十幾個形狀要捲好幾屏才看得完，而使用者在找的
    // 那一個十之八九不在第一屏。插進畫布之後尺寸本來就要自己調。
    LazyVerticalGrid(
        columns = GridCells.Adaptive(52.dp),
        modifier = Modifier.heightIn(max = 220.dp)
    ) {
        items(kinds) { kind ->
            val label = shapeKindLabel(kind, languageTag)
            val semantic = shapeSemantic(kind)
            Box(
                Modifier
                    .padding(3.dp)
                    .size(46.dp)
                    .clickable { onPick(kind) }
                    // 名稱與 ISO 5807 的語意進無障礙標籤，格子本身維持乾淨。
                    .semantics {
                        contentDescription = if (semantic != null) "$label（$semantic）" else label
                    },
                contentAlignment = Alignment.Center
            ) {
                // 名稱與 ISO 5807 的語意改走長按說明 —— 每格掛兩行字的話，
                // 格子就小不下來。
                ShapeThumbnail(kind)
            }
        }
    }
}

/**
 * 形狀的顯示名稱。
 *
 * 走語系表而不是 [NoteShape.nameOf] —— 後者是**持久化用的識別字**
 * （小寫的列舉名），拿來顯示的話中文介面裡會出現「arrowblockright」。
 */
internal fun shapeKindLabel(kind: FfiShapeKind, languageTag: String): String {
    val id = NoteShape.nameOf(kind)
    val localized = LocalizationStrings.localized("shape_kind_$id", languageTag)
    // 語系表裡沒有的（核心加了形狀但字串還沒補）退回識別字，不要給空白。
    return if (localized == "shape_kind_$id") id else localized
}

/** 形狀的縮圖。與畫布上畫的是同一組頂點。 */
@Composable
private fun ShapeThumbnail(kind: FfiShapeKind) {
    val color = MaterialTheme.colorScheme.onSurface
    Box(Modifier.size(40.dp, 28.dp)) {
        Canvas(Modifier.size(40.dp, 28.dp)) {
            val points = shapeOutline(
                FfiShape(
                    kind = kind,
                    bounds = FfiRect(2f, 2f, size.width - 2f, size.height - 2f),
                    cornerRadius = 4f,
                    // 選單裡的預覽一律正放，才比較得出形狀本身的差別。
                    rotationDegrees = 0f
                ),
                40u
            )
            // 線、箭頭、雙箭頭的輪廓只有兩個點。用 `< 3` 擋掉的話它們整格
            // 都是空白 —— 選單裡那三格看起來像壞掉（實際發生過）。
            if (points.size < 2) return@Canvas
            val linear = shapeIsLinear(kind)
            val path = Path().apply {
                moveTo(points[0].x, points[0].y)
                points.drop(1).forEach { lineTo(it.x, it.y) }
                // 線狀形狀不能收尾：折回去就成了零面積的圖形。
                if (!linear) close()
            }
            drawPath(path, color, style = Stroke(width = 1.5f))

            if (linear) {
                val heads = shapeArrowHeads(
                    FfiShape(
                        kind = kind,
                        bounds = FfiRect(2f, 2f, size.width - 2f, size.height - 2f),
                        cornerRadius = 4f,
                        rotationDegrees = 0f
                    ),
                    8f
                )
                for (head in listOf(heads.start, heads.end)) {
                    if (head.size < 3) continue
                    val tri = Path().apply {
                        moveTo(head[0].x, head[0].y)
                        head.drop(1).forEach { lineTo(it.x, it.y) }
                        close()
                    }
                    drawPath(tri, color)
                }
            }
        }
    }
}
