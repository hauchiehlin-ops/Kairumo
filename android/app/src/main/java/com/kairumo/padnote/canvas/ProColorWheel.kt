package com.kairumo.padnote.canvas

import android.graphics.SweepGradient
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.kairumo.padnote.LocalizationStrings
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin

/**
 * 專業手繪工作室 HSV 色相環與色彩和諧調色盤（Android 端）。
 *
 * 參考 CSP / Sketchbook / ibisPaint 專業繪圖軟體：
 * - 360° 漸層色相外環 (Hue Wheel)
 * - 飽和度 (Saturation) 與 明度 (Value) 精準滑桿
 * - 色彩和弦推薦 (Harmonies)：主色、互補色 (+180°)、類似色 (±30°)、三等角色 (+120°, +240°)
 */
@Composable
fun ProColorWheelDialog(
    languageTag: String,
    initialHex: String,
    onPick: (String) -> Unit,
    onDismiss: () -> Unit
) {
    fun l(key: String) = LocalizationStrings.localized(key, languageTag)

    // 初始化 HSV
    var hue by remember {
        val hsv = FloatArray(3)
        runCatching {
            val colorInt = android.graphics.Color.parseColor(initialHex)
            android.graphics.Color.colorToHSV(colorInt, hsv)
        }
        mutableFloatStateOf(hsv[0]) // 0..360
    }
    var saturation by remember {
        val hsv = FloatArray(3)
        runCatching {
            val colorInt = android.graphics.Color.parseColor(initialHex)
            android.graphics.Color.colorToHSV(colorInt, hsv)
        }
        mutableFloatStateOf(if (hsv[1] == 0f && initialHex == "#000000") 1f else hsv[1])
    }
    var value by remember {
        val hsv = FloatArray(3)
        runCatching {
            val colorInt = android.graphics.Color.parseColor(initialHex)
            android.graphics.Color.colorToHSV(colorInt, hsv)
        }
        mutableFloatStateOf(if (initialHex == "#000000") 0f else hsv[2])
    }

    fun currentColorInt(h: Float = hue, s: Float = saturation, v: Float = value): Int {
        val normalizedH = (h % 360f + 360f) % 360f
        return android.graphics.Color.HSVToColor(floatArrayOf(normalizedH, s, v))
    }

    fun currentHex(h: Float = hue, s: Float = saturation, v: Float = value): String {
        val colorInt = currentColorInt(h, s, v)
        return String.format("#%06X", 0xFFFFFF and colorInt)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text(
                text = l("pro_color"),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold)
            )
        },
        confirmButton = {
            TextButton(onClick = { onPick(currentHex()) }) {
                Text(l("confirm"))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(l("cancel"))
            }
        },
        text = {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                // 1. 色相環與當前色彩預覽
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier.size(200.dp)
                ) {
                    Canvas(
                        modifier = Modifier
                            .size(190.dp)
                            .pointerInput(Unit) {
                                detectDragGestures(
                                    onDragStart = { offset ->
                                        val cx = size.width / 2f
                                        val cy = size.height / 2f
                                        val angleRad = atan2(offset.y - cy, offset.x - cx)
                                        var angleDeg = Math.toDegrees(angleRad.toDouble()).toFloat()
                                        if (angleDeg < 0) angleDeg += 360f
                                        hue = angleDeg
                                    },
                                    onDrag = { change, _ ->
                                        change.consume()
                                        val cx = size.width / 2f
                                        val cy = size.height / 2f
                                        val angleRad = atan2(change.position.y - cy, change.position.x - cx)
                                        var angleDeg = Math.toDegrees(angleRad.toDouble()).toFloat()
                                        if (angleDeg < 0) angleDeg += 360f
                                        hue = angleDeg
                                    }
                                )
                            }
                    ) {
                        val strokeW = 28.dp.toPx()
                        val cx = size.width / 2f
                        val cy = size.height / 2f
                        val radius = (size.minDimension - strokeW) / 2f

                        // 繪製 360 度色相環
                        val colors = intArrayOf(
                            android.graphics.Color.RED,
                            android.graphics.Color.YELLOW,
                            android.graphics.Color.GREEN,
                            android.graphics.Color.CYAN,
                            android.graphics.Color.BLUE,
                            android.graphics.Color.MAGENTA,
                            android.graphics.Color.RED
                        )
                        val shader = SweepGradient(cx, cy, colors, null)
                        val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                            this.style = android.graphics.Paint.Style.STROKE
                            this.strokeWidth = strokeW
                            this.shader = shader
                        }
                        drawContext.canvas.nativeCanvas.drawCircle(cx, cy, radius, paint)

                        // 繪製指示環
                        val rad = Math.toRadians(hue.toDouble())
                        val indicatorX = cx + (radius * cos(rad)).toFloat()
                        val indicatorY = cy + (radius * sin(rad)).toFloat()

                        drawCircle(
                            color = Color.White,
                            radius = 10.dp.toPx(),
                            center = androidx.compose.ui.geometry.Offset(indicatorX, indicatorY),
                            style = Stroke(width = 3.dp.toPx())
                        )
                    }

                    // 核心預覽卡片
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(56.dp, 36.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(Color(currentColorInt()))
                                .border(2.dp, Color.White, RoundedCornerShape(8.dp))
                        )
                        Text(
                            text = currentHex(),
                            fontFamily = FontFamily.Monospace,
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                // 2. 飽和度 (Saturation) 與明度 (Value) 滑桿
                Column(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text("S", fontWeight = FontWeight.Bold, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Slider(
                            value = saturation,
                            onValueChange = { saturation = it },
                            modifier = Modifier.weight(1f)
                        )
                        Text("${(saturation * 100).toInt()}%", fontSize = 10.sp, modifier = Modifier.width(32.dp))
                    }

                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text("V", fontWeight = FontWeight.Bold, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        Slider(
                            value = value,
                            onValueChange = { value = it },
                            modifier = Modifier.weight(1f)
                        )
                        Text("${(value * 100).toInt()}%", fontSize = 10.sp, modifier = Modifier.width(32.dp))
                    }
                }

                HorizontalDivider()

                // 3. 色彩和弦推薦 (Harmonies)
                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = l("cw_harmonies"),
                        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        HarmonyColorChip(title = l("cw_primary"), hex = currentHex(hue)) { h -> hue = h }
                        HarmonyColorChip(title = l("cw_complement"), hex = currentHex(hue + 180f)) { h -> hue = (hue + 180f) % 360f }
                        HarmonyColorChip(title = l("cw_analogous"), hex = currentHex(hue + 30f)) { h -> hue = (hue + 30f) % 360f }
                        HarmonyColorChip(title = l("cw_triadic"), hex = currentHex(hue + 120f)) { h -> hue = (hue + 120f) % 360f }
                    }
                }
            }
        }
    )
}

@Composable
private fun HarmonyColorChip(
    title: String,
    hex: String,
    onSelect: (Float) -> Unit
) {
    val color = runCatching { Color(android.graphics.Color.parseColor(hex)) }.getOrDefault(Color.Gray)
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable {
                val hsv = FloatArray(3)
                android.graphics.Color.colorToHSV(android.graphics.Color.parseColor(hex), hsv)
                onSelect(hsv[0])
            }
            .padding(2.dp)
    ) {
        Box(
            modifier = Modifier
                .size(24.dp)
                .clip(CircleShape)
                .background(color)
                .border(1.dp, Color.White.copy(alpha = 0.8f), CircleShape)
        )
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall.copy(fontSize = 9.sp),
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
