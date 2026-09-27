package com.kairumo.padnote.ink

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings

/**
 * 實體擬真筆身幾何與渲染元件（Android Jetpack Compose 對等實作）。
 * 具備 Apple 模式之物理浮起動畫（-10.dp 抬升與環境陰影投射）以及即時墨水染色。
 */
@Composable
fun RealisticPenItem(
    tool: InkTool,
    isSelected: Boolean,
    inkColor: Color,
    strokeWidth: Float,
    languageTag: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    // 物理浮起動畫：選取時向上抬升 10dp，具備流暢物理彈簧曲線
    val offsetY by animateDpAsState(
        targetValue = if (isSelected) (-10).dp else 0.dp,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy, stiffness = Spring.StiffnessLow),
        label = "penElevation"
    )

    val elevationShadow by animateDpAsState(
        targetValue = if (isSelected) 6.dp else 1.dp,
        label = "penShadow"
    )

    val toolLabel = LocalizationStrings.localized(tool.labelKey, languageTag)

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .testTag(tool.parityIdentifier)
            .clickable(onClick = onClick)
            .padding(horizontal = 3.dp, vertical = 2.dp)
            .semantics {
                contentDescription = toolLabel
                stateDescription = if (isSelected) "selected" else "unselected"
            }
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .offset(y = offsetY)
                .shadow(elevationShadow, shape = MaterialTheme.shapes.extraSmall)
                .size(width = 24.dp, height = 54.dp)
        ) {
            Canvas(modifier = Modifier.size(width = 24.dp, height = 54.dp)) {
                when (tool) {
                    InkTool.FOUNTAIN_PEN, InkTool.BRUSH, InkTool.WATERCOLOR ->
                        drawFountainPen(inkColor, isSelected, strokeWidth)
                    InkTool.BALLPOINT ->
                        drawBallpoint(inkColor, isSelected)
                    InkTool.HIGHLIGHTER, InkTool.MARKER ->
                        drawHighlighter(inkColor, isSelected)
                    InkTool.PENCIL ->
                        drawPencil(inkColor, isSelected)
                    InkTool.ERASER ->
                        drawEraser(isSelected)
                    InkTool.LASSO ->
                        drawLasso(isSelected)
                    InkTool.MASKING_TAPE ->
                        drawMaskingTape(isSelected)
                }
            }
        }

        Text(
            text = toolLabel,
            fontSize = 9.sp,
            color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 2.dp)
        )
    }
}

// MARK: - Draw Helpers

private fun DrawScope.drawFountainPen(color: Color, isSelected: Boolean, strokeWidth: Float) {
    val w = size.width
    val h = size.height

    // 1. 金屬筆尖
    val nib = Path().apply {
        moveTo(w * 0.5f, 0f)
        lineTo(w * 0.95f, h * 0.28f)
        lineTo(w * 0.05f, h * 0.28f)
        close()
    }
    drawPath(
        path = nib,
        brush = Brush.linearGradient(
            colors = listOf(Color(0xFFE8E8E8), Color(0xFFAAAAAA), Color(0xFFD0D0D0))
        )
    )

    // 筆尖墨水沾染
    val tipInk = Path().apply {
        moveTo(w * 0.5f, 0f)
        lineTo(w * 0.72f, h * 0.14f)
        lineTo(w * 0.28f, h * 0.14f)
        close()
    }
    drawPath(path = tipInk, color = color)

    // 2. 金屬領圈
    drawRect(
        brush = Brush.horizontalGradient(listOf(Color(0xFFD5D5D5), Color(0xFF888888), Color(0xFFE0E0E0))),
        topLeft = Offset(0f, h * 0.28f),
        size = Size(w, h * 0.06f)
    )

    // 3. 染色墨水環
    drawRect(
        color = color,
        topLeft = Offset(0f, h * 0.34f),
        size = Size(w, h * 0.08f)
    )

    // 4. 曜石黑啞光筆桿
    drawRect(
        brush = Brush.horizontalGradient(listOf(Color(0xFF383838), Color(0xFF1E1E1E), Color(0xFF2E2E2E))),
        topLeft = Offset(0f, h * 0.42f),
        size = Size(w, h * 0.58f)
    )
}

private fun DrawScope.drawBallpoint(color: Color, isSelected: Boolean) {
    val w = size.width
    val h = size.height

    // 滾珠尖
    drawCircle(
        color = color,
        radius = w * 0.1f,
        center = Offset(w * 0.5f, h * 0.06f)
    )

    // 針管金屬套管
    drawRect(
        color = Color(0xFFCCCCCC),
        topLeft = Offset(w * 0.38f, h * 0.08f),
        size = Size(w * 0.24f, h * 0.16f)
    )

    // 階梯金屬承座
    val base = Path().apply {
        moveTo(w * 0.35f, h * 0.24f)
        lineTo(w * 0.65f, h * 0.24f)
        lineTo(w * 0.95f, h * 0.34f)
        lineTo(w * 0.05f, h * 0.34f)
        close()
    }
    drawPath(base, color = Color(0xFFAAAAAA))

    // 色環
    drawRect(
        color = color,
        topLeft = Offset(0f, h * 0.34f),
        size = Size(w, h * 0.08f)
    )

    // 筆桿
    drawRect(
        brush = Brush.horizontalGradient(listOf(Color(0xFFE0E0E0), Color(0xFFB5B5B5), Color(0xFFD8D8D8))),
        topLeft = Offset(0f, h * 0.42f),
        size = Size(w, h * 0.58f)
    )
}

private fun DrawScope.drawHighlighter(color: Color, isSelected: Boolean) {
    val w = size.width
    val h = size.height

    // 斜切鑿形筆頭
    val chisel = Path().apply {
        moveTo(w * 0.2f, 0f)
        lineTo(w * 0.88f, h * 0.08f)
        lineTo(w * 0.82f, h * 0.24f)
        lineTo(w * 0.18f, h * 0.24f)
        close()
    }
    drawPath(chisel, color = color.copy(alpha = 0.92f))

    // 黑色筆頸
    drawRect(
        color = Color(0xFF222222),
        topLeft = Offset(w * 0.1f, h * 0.24f),
        size = Size(w * 0.8f, h * 0.10f)
    )

    // 粗厚方圓筆身
    drawRect(
        brush = Brush.horizontalGradient(listOf(Color(0xFF424242), Color(0xFF262626))),
        topLeft = Offset(0f, h * 0.34f),
        size = Size(w, h * 0.66f)
    )

    // 筆身大螢光條
    drawRect(
        color = color.copy(alpha = 0.85f),
        topLeft = Offset(w * 0.2f, h * 0.48f),
        size = Size(w * 0.6f, h * 0.32f)
    )
}

private fun DrawScope.drawPencil(color: Color, isSelected: Boolean) {
    val w = size.width
    val h = size.height

    // 木質削錐
    val cone = Path().apply {
        moveTo(w * 0.5f, 0f)
        lineTo(w * 0.95f, h * 0.28f)
        lineTo(w * 0.05f, h * 0.28f)
        close()
    }
    drawPath(cone, color = Color(0xFFDFB887))

    // 石墨筆芯尖
    val lead = Path().apply {
        moveTo(w * 0.5f, 0f)
        lineTo(w * 0.68f, h * 0.10f)
        lineTo(w * 0.32f, h * 0.10f)
        close()
    }
    drawPath(lead, color = Color(0xFF2D2D2D))

    // 金黃六角鉛筆桿
    drawRect(
        brush = Brush.horizontalGradient(
            listOf(Color(0xFFF5AC27), Color(0xFFD48B10), Color(0xFFF7BD48))
        ),
        topLeft = Offset(0f, h * 0.28f),
        size = Size(w, h * 0.72f)
    )
}

private fun DrawScope.drawEraser(isSelected: Boolean) {
    val w = size.width
    val h = size.height

    // 櫻花粉紅橡皮頭
    drawRoundRect(
        color = Color(0xFFF8A5B8),
        topLeft = Offset(w * 0.08f, 0f),
        size = Size(w * 0.84f, h * 0.38f),
        cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f)
    )

    // 金屬固定箍
    drawRect(
        brush = Brush.horizontalGradient(listOf(Color(0xFFCCCCCC), Color(0xFF777777))),
        topLeft = Offset(0f, h * 0.36f),
        size = Size(w, h * 0.10f)
    )

    // 黑色握把
    drawRect(
        color = Color(0xFF252525),
        topLeft = Offset(0f, h * 0.46f),
        size = Size(w, h * 0.54f)
    )
}

private fun DrawScope.drawLasso(isSelected: Boolean) {
    val w = size.width
    val h = size.height

    // 手寫筆圓珠尖
    drawCircle(
        color = Color(0xFF555555),
        radius = w * 0.12f,
        center = Offset(w * 0.5f, h * 0.06f)
    )

    // 錐形尖
    val cone = Path().apply {
        moveTo(w * 0.35f, h * 0.08f)
        lineTo(w * 0.65f, h * 0.08f)
        lineTo(w * 0.95f, h * 0.26f)
        lineTo(w * 0.05f, h * 0.26f)
        close()
    }
    drawPath(cone, color = Color(0xFFE2E2E2))

    // 白銀金屬筆身
    drawRect(
        brush = Brush.horizontalGradient(listOf(Color(0xFFF2F2F2), Color(0xFFD6D6D6), Color(0xFFEBEBEB))),
        topLeft = Offset(0f, h * 0.26f),
        size = Size(w, h * 0.74f)
    )

    // 套索環色環
    drawRect(
        color = Color(0xFF007AFF),
        topLeft = Offset(0f, h * 0.44f),
        size = Size(w, h * 0.08f)
    )
}

private fun DrawScope.drawMaskingTape(isSelected: Boolean) {
    val w = size.width
    val h = size.height

    // 鋸齒和紙膠帶頭
    val teeth = Path().apply {
        moveTo(0f, h * 0.18f)
        lineTo(w * 0.25f, 0f)
        lineTo(w * 0.5f, h * 0.12f)
        lineTo(w * 0.75f, 0f)
        lineTo(w, h * 0.18f)
        lineTo(w, h)
        lineTo(0f, h)
        close()
    }
    drawPath(teeth, color = Color(0xFFE8DCBA))

    // 膠帶中線紋理
    drawRect(
        color = Color(0xFFD4C59E),
        topLeft = Offset(w * 0.2f, h * 0.3f),
        size = Size(w * 0.6f, h * 0.5f)
    )
}
