package com.kairumo.padnote.canvas

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.ink.InkEngine

/**
 * 套索層：手勢與那一圈虛線都在這裡，疊在畫布**上面**。
 *
 * # 為什麼疊一層而不是接在畫布上
 *
 * 與 Apple 端同一個結論。那邊試過在 `PKCanvasView` 上加手勢辨識器，
 * 怎麼調都不觸發（PencilKit 內部還有自己的觸控處理）。這裡雖然是自己的
 * 畫布、接得到，但疊一層仍然比較好：**套索模式下畫布完全收不到事件**，
 * 不必在 `InkEngine` 裡加一堆「現在是不是套索模式」的分支，
 * 而那種分支正是墨跡路徑最不該有的東西。
 *
 * 離開套索模式這一層就不存在，畫布的行為一行都沒變。
 *
 * # 虛線不進筆畫
 *
 * 它只是一個暫時的選取提示。畫進 `InkEngine` 的話會被存檔、被匯出、
 * 被同步到另一台裝置。
 */
@Composable
fun LassoOverlay(
    lasso: LassoSelection,
    engine: InkEngine,
    modifier: Modifier = Modifier,
    /**
     * 這一層開始一次圈選或拖曳之前呼叫。連續頁面模式每一頁各一層、共用一份選取：
     * 在別頁圈下去時，呼叫端在這裡把選取清掉、把「選取屬於哪一頁」換成這一頁。
     */
    onGestureStart: () -> Unit = {},
    /** 圈、選取框與拖曳預覽要不要畫在這一層（連續模式只畫在選取所屬的那一頁）。 */
    showDecoration: Boolean = true,
    /**
     * 拖曳中在這一層另外畫一份選中筆畫。一般畫布不需要：它自己會把選中的筆畫畫在新位置
     * （`InkCanvas` 的 `lassoDrag`）。低延遲畫布畫在另一個 SurfaceView 上做不到，才靠這一份。
     */
    drawDragPreview: Boolean = false,
    objectCandidates: List<MarqueeHit> = emptyList(),
    lockedObjectIds: Set<String> = emptySet(),
    imageStore: com.kairumo.padnote.image.ImageStore? = null,
    textStore: com.kairumo.padnote.text.TextBoxStore? = null,
    tableStore: com.kairumo.padnote.table.TableStore? = null,
    chartStore: com.kairumo.padnote.chart.ChartStore? = null,
    shapeStore: com.kairumo.padnote.shape.ShapeStore? = null,
    onChanged: () -> Unit
) {
    val density = LocalDensity.current.density
    val accent = MaterialTheme.colorScheme.primary
    // 不拿它當 pointerInput 的 key：每次重組都是新的 lambda，當 key 會把進行中的手勢拆掉。
    val gestureStart by rememberUpdatedState(onGestureStart)
    val candidatesLatest by rememberUpdatedState(objectCandidates)
    val lockedLatest by rememberUpdatedState(lockedObjectIds)
    val changedLatest by rememberUpdatedState(onChanged)

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .pointerInput(engine) {
                // 這一層在畫布的 `graphicsLayer` 裡面，收到的位置已經扣掉縮放與捲動，
                // 只差一個 density 就是頁面點（與核心筆畫同一套）。
                detectDragGestures(
                    onDragStart = {
                        gestureStart()
                        if (imageStore != null && textStore != null && tableStore != null && chartStore != null && shapeStore != null) {
                            lasso.bindPageObjects(
                                candidatesLatest, lockedLatest,
                                imageStore, textStore, tableStore, chartStore, shapeStore,
                                onMutated = changedLatest
                            )
                        }
                        lasso.begin(it / density)
                    },
                    onDrag = { change, _ ->
                        lasso.extend(change.position / density)
                        // 消費掉，底下的東西不要再看到這一筆。
                        change.consume()
                    },
                    onDragEnd = {
                        lasso.finish(engine)
                        onChanged()
                    },
                    // 被取消（例如長按叫出飛梭工具盤）：只收掉這一圈／這一次拖曳，已有的選取留著。
                    onDragCancel = { lasso.cancelGesture(); onChanged() }
                )
            }
    ) {
        if (!showDecoration) return@Canvas
        val drag = lasso.dragOffset
        val points = lasso.path.ifEmpty { lasso.committed.map { it + drag } }

        // 拖曳中：選中的筆畫跟著手指畫一份預覽（只有畫布自己畫不了位移時）。放開才真的搬（見 LassoSelection.dragOffset）。
        if (drawDragPreview && lasso.isDragging && drag != Offset.Zero) {
            val ids = lasso.selected.toSet()
            for (stroke in engine.strokes) {
                if (stroke.coreStrokeId !in ids || stroke.points.size < 2) continue
                val p = Path().apply {
                    moveTo((stroke.points[0].x + drag.x) * density, (stroke.points[0].y + drag.y) * density)
                    for (pt in stroke.points.drop(1)) lineTo((pt.x + drag.x) * density, (pt.y + drag.y) * density)
                }
                drawPath(p, color = accent.copy(alpha = 0.55f),
                    style = Stroke(width = stroke.baseWidth * density))
            }
        }

        // 選取框 ＝ 圈 ∪ 選中筆畫的外框：露出圈外的筆畫也在框內，拖那一段一樣拖得動。
        if (lasso.hasSelection && lasso.path.isEmpty()) {
            lasso.boundingRect?.let { box ->
                val r = box.translate(drag).inflate(8f)
                drawRoundRect(
                    color = accent.copy(alpha = 0.35f),
                    topLeft = Offset(r.left * density, r.top * density),
                    size = androidx.compose.ui.geometry.Size(r.width * density, r.height * density),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(8f * density),
                    style = Stroke(
                        width = 1.2f * density,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(5f * density, 4f * density))
                    )
                )
            }
        }

        if (points.size < 2) return@Canvas

        val path = Path().apply {
            moveTo(points.first().x * density, points.first().y * density)
            points.drop(1).forEach { lineTo(it.x * density, it.y * density) }
            // 圈完之後才封閉：畫的當下封起來，使用者看到的是一個
            // 隨著手指亂跳的三角形，而不是他正在畫的那一條線。
            if (lasso.path.isEmpty()) close()
        }
        drawPath(
            path = path,
            color = accent.copy(alpha = if (lasso.path.isEmpty()) 0.7f else 0.9f),
            style = Stroke(
                width = 1.5f * density,
                pathEffect = PathEffect.dashPathEffect(
                    floatArrayOf(6f * density, 4f * density)
                )
            )
        )
    }
}

/**
 * 選取工具列在畫面上的位置（像素，畫布可視範圍的座標）：選取框上方置中，
 * 上方放不下（貼著可視範圍頂端）就改放在下方。與 Apple 的 `lassoSelectionDecoration` 同一個規則。
 *
 * 頁面點 → 畫面：乘 density 與縮放、加上捲動位移。
 */
fun lassoBarAnchor(
    box: Rect,
    density: Float,
    scale: Float,
    offset: Offset,
    barHeightPx: Float,
    gapPx: Float
): Offset {
    val k = density * scale
    val left = box.left * k + offset.x
    val top = box.top * k + offset.y
    val right = box.right * k + offset.x
    val bottom = box.bottom * k + offset.y
    val above = top - gapPx - barHeightPx
    val y = if (above >= gapPx) above else bottom + gapPx
    return Offset((left + right) / 2f, y)
}

/**
 * 套索模式、沒有選取、剪貼簿有筆跡時的「貼上」入口（畫面上方）。
 *
 * 選取工具列只在有選取時出現；剪下之後選取就清空了，不另外給入口的話
 * 剪下來的東西就再也貼不回去。
 */
@Composable
fun LassoPastePill(
    lasso: LassoSelection,
    engine: InkEngine,
    l: (String) -> String,
    onChanged: () -> Unit,
    modifier: Modifier = Modifier
) {
    if (lasso.hasSelection || lasso.path.isNotEmpty() || !lasso.canPaste) return
    Card(
        modifier = modifier.testTag("editor.lasso.paste"),
        shape = RoundedCornerShape(50),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        TextButton(onClick = { if (lasso.paste(engine)) onChanged() }) {
            Text("📋 " + l("paste_strokes"), fontSize = 13.sp, color = MaterialTheme.colorScheme.primary)
        }
    }
}

/**
 * 選取之後的快顯動作列（浮在選取框旁邊，位置見 [lassoBarAnchor]）。
 *
 * **只在有選取時出現**；沒有選取但剪貼簿有東西時由 [LassoPastePill] 給貼上入口。
 * 貼上鈕只在剪貼簿有東西時出現 —— 空的貼上鈕按下去什麼也不會發生。
 */
@Composable
fun LassoActionBar(
    lasso: LassoSelection,
    engine: InkEngine,
    l: (String) -> String,
    onChanged: () -> Unit,
    onRecognizeToText: (() -> Unit)? = null,
    onAnchorToText: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    if (!lasso.hasSelection || lasso.path.isNotEmpty() || lasso.isDragging) return

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                "🔗",
                fontSize = 14.sp,
                modifier = Modifier.padding(horizontal = 4.dp)
            )
            if (lasso.hasSelection) {
                TextButton(onClick = { if (lasso.cut(engine)) onChanged() }) {
                    Text(l("cut_selected"), fontSize = 12.sp)
                }
                TextButton(onClick = { lasso.copy(engine) }) {
                    Text(l("copy_selected"), fontSize = 12.sp)
                }
                TextButton(onClick = { if (lasso.duplicate(engine)) onChanged() }) {
                    Text(l("duplicate_selected"), fontSize = 12.sp)
                }
                if (onRecognizeToText != null) {
                    TextButton(onClick = { onRecognizeToText() }) {
                        Text(l("recognize_handwriting"), fontSize = 12.sp)
                    }
                }
                if (onAnchorToText != null) {
                    TextButton(onClick = { onAnchorToText() }) {
                        Text(l("sticky_anchor_text"), fontSize = 12.sp)
                    }
                }
            }
            if (lasso.canPaste) {
                TextButton(onClick = { if (lasso.paste(engine)) onChanged() }) {
                    Text(l("paste_strokes"), fontSize = 12.sp)
                }
            }
            if (lasso.hasSelection) {
                TextButton(onClick = { if (lasso.delete(engine)) onChanged() }) {
                    Text(
                        l("delete_selected"),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.error
                    )
                }
            }
            TextButton(onClick = {
                lasso.clear()
                onChanged()
            }) {
                Text(
                    "✕ " + l("cancel"),
                    fontSize = 12.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

/**
 * 把選取工具列放到 [lassoBarAnchor] 算出的位置，並夾在父層範圍內（左右不出界、上下不出界）。
 * 放在畫布 `graphicsLayer` **外面**那一層用：工具列不跟著頁面縮放，按鈕維持原尺寸。
 */
fun Modifier.lassoBarPlacement(
    box: Rect,
    density: Float,
    scale: Float,
    offset: Offset,
    gapPx: Float
): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints.copy(minWidth = 0, minHeight = 0))
    val w = constraints.maxWidth
    val h = constraints.maxHeight
    layout(w, h) {
        val anchor = lassoBarAnchor(box, density, scale, offset, placeable.height.toFloat(), gapPx)
        val x = (anchor.x - placeable.width / 2f).coerceIn(0f, maxOf(0f, (w - placeable.width).toFloat()))
        val y = anchor.y.coerceIn(0f, maxOf(0f, (h - placeable.height).toFloat()))
        placeable.place(x.toInt(), y.toInt())
    }
}
