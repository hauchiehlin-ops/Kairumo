package com.kairumo.padnote.theme

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke

/**
 * 構圖輔助疊層（Android）。
 *
 * 黃金螺旋與三分構圖，與 Apple 的 `GoldenSpiralOverlayView` /
 * `RuleOfThirdsOverlayView` 同樣的幾何與同樣的虛線樣式。
 *
 * **不吃觸控。** 這是參考線，不是內容 —— 會擋住筆的疊層等於把畫布鎖住。
 * 呼叫端不要在它上面掛任何手勢。
 */
@Composable
fun CompositionOverlay(
    goldenSpiral: Boolean,
    ruleOfThirds: Boolean,
    modifier: Modifier = Modifier
) {
    if (!goldenSpiral && !ruleOfThirds) return

    Canvas(modifier) {
        if (goldenSpiral) drawGoldenSpiral(size.width, size.height, this)
        if (ruleOfThirds) drawRuleOfThirds(size.width, size.height, this)
    }
}

private const val PHI = 1.6180339887f

private fun drawGoldenSpiral(w: Float, h: Float, scope: androidx.compose.ui.graphics.drawscope.DrawScope) {
    val minDim = minOf(w, h * 0.8f)
    val path = Path()

    var curW = minDim
    var curH = minDim / PHI
    var x = maxOf(20f, (w - curW) / 2f)
    val y = 60f

    path.addRect(Rect(Offset(x, y), Size(curW, curH)))

    repeat(7) {
        val square = curH
        path.addRect(Rect(Offset(x, y), Size(square, square)))
        // 四分之一圓弧，圓心在方格的右下角、半徑等於邊長 —— 一格接一格
        // 連起來就是螺旋。外接矩形是「圓心 ± 半徑」，所以邊長是 2×square。
        path.addArc(
            Rect(Offset(x, y), Size(square * 2f, square * 2f)),
            180f,
            90f
        )
        x += square
        // 下一格的寬高互換：剩下的那一塊又是一個黃金矩形。
        val remaining = curW - square
        curH = remaining
        curW = square
    }

    scope.drawPath(
        path,
        color = Color(0xFFFF9500).copy(alpha = 0.65f),
        style = Stroke(
            width = 1.5f,
            pathEffect = PathEffect.dashPathEffect(floatArrayOf(4f, 3f))
        )
    )
}

private fun drawRuleOfThirds(w: Float, h: Float, scope: androidx.compose.ui.graphics.drawscope.DrawScope) {
    // 與 Apple 端一致：超過 1200 點的頁面只在前 1200 點畫格線 ——
    // 三分構圖是針對一個畫面，整張長頁拉滿反而失去意義。
    val activeHeight = minOf(h, 1200f)
    val color = Color(0xFF32ADE6).copy(alpha = 0.7f)
    val stroke = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))

    val path = Path().apply {
        moveTo(w / 3f, 0f); lineTo(w / 3f, activeHeight)
        moveTo(w * 2f / 3f, 0f); lineTo(w * 2f / 3f, activeHeight)
        moveTo(0f, activeHeight / 3f); lineTo(w, activeHeight / 3f)
        moveTo(0f, activeHeight * 2f / 3f); lineTo(w, activeHeight * 2f / 3f)
    }
    scope.drawPath(path, color = color, style = Stroke(width = 1.5f, pathEffect = stroke))

    // 四個交點是視覺重心，標出來才是「三分法」而不只是格線。
    for (p in listOf(
        Offset(w / 3f, activeHeight / 3f),
        Offset(w * 2f / 3f, activeHeight / 3f),
        Offset(w / 3f, activeHeight * 2f / 3f),
        Offset(w * 2f / 3f, activeHeight * 2f / 3f)
    )) {
        scope.drawCircle(color = color, radius = 4f, center = p)
    }
}
