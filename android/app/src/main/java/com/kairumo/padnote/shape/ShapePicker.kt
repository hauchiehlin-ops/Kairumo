package com.kairumo.padnote.shape

import androidx.compose.foundation.Canvas
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
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(l("shape_studio")) },
        confirmButton = {},
        dismissButton = { TextButton(onClick = onDismiss) { Text(l("cancel")) } },
        text = {
            Column(
                Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Text(l("shape_section_basic"), style = MaterialTheme.typography.titleSmall)
                KindGrid(allShapeKinds().filter { it !in flowchartShapeKinds() }) { kind ->
                    onCommit(listOf(NoteShape(kindName = NoteShape.nameOf(kind))), emptyList())
                }

                HorizontalDivider()
                Text(l("shape_section_flowchart"), style = MaterialTheme.typography.titleSmall)
                KindGrid(flowchartShapeKinds()) { kind ->
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
private fun KindGrid(kinds: List<FfiShapeKind>, onPick: (FfiShapeKind) -> Unit) {
    LazyVerticalGrid(
        columns = GridCells.Adaptive(84.dp),
        modifier = Modifier.heightIn(max = 200.dp)
    ) {
        items(kinds) { kind ->
            TextButton(onClick = { onPick(kind) }) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    ShapeThumbnail(kind)
                    Text(NoteShape.nameOf(kind), fontSize = 9.sp, maxLines = 1)
                    // ISO 5807 的語意直接寫出來 —— 沒有人記得哪個符號代表什麼。
                    shapeSemantic(kind)?.let {
                        Text(
                            it,
                            fontSize = 8.sp,
                            maxLines = 1,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }
        }
    }
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
            if (points.size < 3) return@Canvas
            val path = Path().apply {
                moveTo(points[0].x, points[0].y)
                points.drop(1).forEach { lineTo(it.x, it.y) }
                close()
            }
            drawPath(path, color, style = Stroke(width = 1.5f))
        }
    }
}
