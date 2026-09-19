package com.kairumo.padnote.canvas

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
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
    onChanged: () -> Unit
) {
    val density = LocalDensity.current.density
    val accent = MaterialTheme.colorScheme.primary

    Canvas(
        modifier = modifier
            .fillMaxSize()
            .pointerInput(engine) {
                detectDragGestures(
                    onDragStart = { lasso.begin(it) },
                    onDrag = { change, _ ->
                        lasso.extend(change.position)
                        // 消費掉，底下的東西不要再看到這一筆。
                        change.consume()
                    },
                    onDragEnd = {
                        lasso.finish(engine, density)
                        onChanged()
                    },
                    onDragCancel = { lasso.clear(); onChanged() }
                )
            }
    ) {
        val points = lasso.path.ifEmpty { lasso.committed }
        if (points.size < 2) return@Canvas

        val path = Path().apply {
            moveTo(points.first().x, points.first().y)
            points.drop(1).forEach { lineTo(it.x, it.y) }
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
 * 選取之後的動作列。
 *
 * **只在真的有東西可以做的時候出現**（有選取，或剪貼簿裡有東西可以貼）。
 * 一選了套索就跳出來的話，那時候每一顆按鈕都是空操作 —— 使用者按下去
 * 什麼也不會發生，而畫面上也沒有任何提示說明為什麼。
 */
@Composable
fun LassoActionBar(
    lasso: LassoSelection,
    engine: InkEngine,
    l: (String) -> String,
    onChanged: () -> Unit,
    onRecognizeToText: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    if (!lasso.hasSelection && !lasso.canPaste) return

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
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
        }
    }
}
